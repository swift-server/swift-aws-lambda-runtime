//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import NIOConcurrencyHelpers

extension Lambda {
    /// `Lifecycle` manages the Lambda process lifecycle.
    ///
    /// - note: It is intended to be used within a single `EventLoop`. For this reason this class is not thread safe.
    public final class Lifecycle {
        private let eventLoop: EventLoop
        private let shutdownPromise: EventLoopPromise<Int>
        private let logger: Logger
        private let configuration: Configuration
        private let factory: HandlerFactory

        private var state = State.idle {
            willSet {
                self.eventLoop.assertInEventLoop()
                precondition(newValue.order > self.state.order, "invalid state \(newValue) after \(self.state.order)")
            }
        }

        /// Create a new `Lifecycle`.
        ///
        /// - parameters:
        ///     - eventLoop: An `EventLoop` to run the Lambda on.
        ///     - logger: A `Logger` to log the Lambda events.
        ///     - factory: A `LambdaHandlerFactory` to create the concrete  Lambda handler.
        public convenience init(eventLoop: EventLoop, logger: Logger, factory: @escaping HandlerFactory) {
            self.init(eventLoop: eventLoop, logger: logger, configuration: .init(), factory: factory)
        }

        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, factory: @escaping HandlerFactory) {
            self.eventLoop = eventLoop
            self.shutdownPromise = eventLoop.makePromise(of: Int.self)
            self.logger = logger
            self.configuration = configuration
            self.factory = factory
        }

        deinit {
            guard case .shutdown = self.state else {
                preconditionFailure("invalid state \(self.state)")
            }
        }

        /// The `Lifecycle` shutdown future.
        ///
        /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda lifecycle has fully shutdown.
        public var shutdownFuture: EventLoopFuture<Int> {
            self.shutdownPromise.futureResult
        }

        /// Start the `Lifecycle`.
        ///
        /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda hander has been created and initiliazed, and a first run has been scheduled.
        ///
        /// - note: This method must be called  on the `EventLoop` the `Lifecycle` has been initialized with.
        public func start() -> EventLoopFuture<Void> {
            self.eventLoop.assertInEventLoop()

            logger.info("lambda lifecycle starting with \(self.configuration)")
            self.state = .initializing

            var logger = self.logger
            logger[metadataKey: "lifecycleId"] = .string(self.configuration.lifecycle.id)
            let runner = Runner(eventLoop: self.eventLoop, configuration: self.configuration)

            let startupFuture = runner.initialize(logger: logger, factory: self.factory)
            startupFuture.flatMap { handler -> EventLoopFuture<(ByteBufferLambdaHandler, Result<Int, Error>)> in
                // after the startup future has succeeded, we have a handler that we can use
                // to `run` the lambda.
                let finishedPromise = self.eventLoop.makePromise(of: Int.self)
                self.state = .active(runner, handler)
                self.run(promise: finishedPromise)
                return finishedPromise.futureResult.mapResult { (handler, $0) }
            }
            .flatMap { (handler, runnerResult) -> EventLoopFuture<Int> in
                // after the lambda finishPromise has succeeded or failed we need to
                // shutdown the handler
                let shutdownContext = ShutdownContext(logger: logger, eventLoop: self.eventLoop)
                return handler.shutdown(context: shutdownContext).flatMapErrorThrowing { error in
                    // if, we had an error shuting down the lambda, we want to concatenate it with
                    // the runner result
                    logger.error("Error shutting down handler: \(error)")
                    throw RuntimeError.shutdownError(shutdownError: error, runnerResult: runnerResult)
                }.flatMapResult { (_) -> Result<Int, Error> in
                    // we had no error shutting down the lambda. let's return the runner's result
                    runnerResult
                }
            }.always { _ in
                // triggered when the Lambda has finished its last run or has a startup failure.
                self.markShutdown()
            }.cascade(to: self.shutdownPromise)

            return startupFuture.map { _ in }
        }

        // MARK: -  Private

        #if DEBUG
        /// Begin the `Lifecycle` shutdown. Only needed for debugging purposes, hence behind a `DEBUG` flag.
        public func shutdown() {
            // make this method thread safe by dispatching onto the eventloop
            self.eventLoop.execute {
                let oldState = self.state
                self.state = .shuttingdown
                if case .active(let runner, _) = oldState {
                    runner.cancelWaitingForNextInvocation()
                }
            }
        }
        #endif

        private func markShutdown() {
            self.state = .shutdown
        }

        @inline(__always)
        private func run(promise: EventLoopPromise<Int>) {
            func _run(_ count: Int) {
                switch self.state {
                case .active(let runner, let handler):
                    if self.configuration.lifecycle.maxTimes > 0, count >= self.configuration.lifecycle.maxTimes {
                        return promise.succeed(count)
                    }
                    var logger = self.logger
                    logger[metadataKey: "lifecycleIteration"] = "\(count)"
                    runner.run(logger: logger, handler: handler).whenComplete { result in
                        switch result {
                        case .success:
                            logger.log(level: .debug, "lambda invocation sequence completed successfully")
                            // recursive! per aws lambda runtime spec the polling requests are to be done one at a time
                            _run(count + 1)
                        case .failure(HTTPClient.Errors.cancelled):
                            if case .shuttingdown = self.state {
                                // if we ware shutting down, we expect to that the get next
                                // invocation request might have been cancelled. For this reason we
                                // succeed the promise here.
                                logger.log(level: .info, "lambda invocation sequence has been cancelled for shutdown")
                                return promise.succeed(count)
                            }
                            logger.log(level: .error, "lambda invocation sequence has been cancelled unexpectedly")
                            promise.fail(HTTPClient.Errors.cancelled)
                        case .failure(let error):
                            logger.log(level: .error, "lambda invocation sequence completed with error: \(error)")
                            promise.fail(error)
                        }
                    }
                case .shuttingdown:
                    promise.succeed(count)
                default:
                    preconditionFailure("invalid run state: \(self.state)")
                }
            }

            _run(0)
        }

        private enum State {
            case idle
            case initializing
            case active(Runner, Handler)
            case shuttingdown
            case shutdown

            internal var order: Int {
                switch self {
                case .idle:
                    return 0
                case .initializing:
                    return 1
                case .active:
                    return 2
                case .shuttingdown:
                    return 3
                case .shutdown:
                    return 4
                }
            }
        }
    }
}
