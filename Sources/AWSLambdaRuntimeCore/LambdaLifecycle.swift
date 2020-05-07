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

        private var _state = State.idle
        private let stateLock = Lock()

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
        /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda hander has been created and initiliazed, and a first run has been schduled.
        public func start() -> EventLoopFuture<Void> {
            logger.info("lambda lifecycle starting with \(self.configuration)")
            self.state = .initializing
            // triggered when the Lambda has finished its last run
            let finishedPromise = self.eventLoop.makePromise(of: Int.self)
            finishedPromise.futureResult.always { _ in
                self.markShutdown()
            }.cascade(to: self.shutdownPromise)
            var logger = self.logger
            logger[metadataKey: "lifecycleId"] = .string(self.configuration.lifecycle.id)
            let runner = Runner(eventLoop: self.eventLoop, configuration: self.configuration)
            return runner.initialize(logger: logger, factory: self.factory).map { handler in
                self.state = .active(runner, handler)
                self.run(promise: finishedPromise)
            }
        }

        // MARK: -  Private

        #if DEBUG
        /// Begin the `Lifecycle` shutdown. Only needed for debugging purposes, hence behind a `DEBUG` flag.
        public func shutdown() {
            // make this method thread safe by dispatching onto the eventloop
            self.eventLoop.execute {
                guard case .active(let runner, _) = self.state else {
                    return
                }
                self.state = .shuttingdown
                runner.cancelWaitingForNextInvocation()
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
                            // recursive! per aws lambda runtime spec the polling requests are to be done one at a time
                            _run(count + 1)
                        case .failure(let error):
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

        private var state: State {
            get {
                self.stateLock.withLock {
                    self._state
                }
            }
            set {
                self.stateLock.withLockVoid {
                    precondition(newValue.order > self._state.order, "invalid state \(newValue) after \(self._state)")
                    self._state = newValue
                }
                self.logger.debug("lambda lifecycle state: \(newValue)")
            }
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
