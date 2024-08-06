//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOConcurrencyHelpers
import NIOCore

/// `LambdaRuntime` manages the Lambda process lifecycle.
///
/// Use this API, if you build a higher level web framework which shall be able to run inside the Lambda environment.
public final class LambdaRuntime<Handler: LambdaRuntimeHandler> {
    private let eventLoop: EventLoop
    private let shutdownPromise: EventLoopPromise<Int>
    private let logger: Logger
    private let configuration: LambdaConfiguration

    private let handlerProvider: (LambdaInitializationContext) -> EventLoopFuture<Handler>

    private var state = State.idle {
        willSet {
            self.eventLoop.assertInEventLoop()
            precondition(newValue.order > self.state.order, "invalid state \(newValue) after \(self.state.order)")
        }
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerProvider: A provider of the ``Handler`` the `LambdaRuntime` will manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @usableFromInline
    convenience init(
        handlerProvider: @escaping (LambdaInitializationContext) -> EventLoopFuture<Handler>,
        eventLoop: EventLoop,
        logger: Logger
    ) {
        self.init(
            handlerProvider: handlerProvider,
            eventLoop: eventLoop,
            logger: logger,
            configuration: .init()
        )
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerProvider: A provider of the ``Handler`` the `LambdaRuntime` will manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    init(
        handlerProvider: @escaping (LambdaInitializationContext) -> EventLoopFuture<Handler>,
        eventLoop: EventLoop,
        logger: Logger,
        configuration: LambdaConfiguration
    ) {
        self.eventLoop = eventLoop
        self.shutdownPromise = eventLoop.makePromise(of: Int.self)
        self.logger = logger
        self.configuration = configuration

        self.handlerProvider = handlerProvider
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

    /// Start the `LambdaRuntime`.
    ///
    /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda hander has been created and initialized, and a first run has been scheduled.
    public func start() -> EventLoopFuture<Void> {
        if self.eventLoop.inEventLoop {
            return self._start()
        } else {
            return self.eventLoop.flatSubmit { self._start() }
        }
    }

    private func _start() -> EventLoopFuture<Void> {
        // This method must be called on the `EventLoop` the `LambdaRuntime` has been initialized with.
        self.eventLoop.assertInEventLoop()

        logger.info("lambda runtime starting with \(self.configuration)")
        self.state = .initializing

        var logger = self.logger
        logger[metadataKey: "lifecycleId"] = .string(self.configuration.lifecycle.id)
        let terminator = LambdaTerminator()
        let runner = LambdaRunner(eventLoop: self.eventLoop, configuration: self.configuration)

        let startupFuture = runner.initialize(handlerProvider: self.handlerProvider, logger: logger, terminator: terminator)
        startupFuture.flatMap { handler -> EventLoopFuture<Result<Int, Error>> in
            // after the startup future has succeeded, we have a handler that we can use
            // to `run` the lambda.
            let finishedPromise = self.eventLoop.makePromise(of: Int.self)
            self.state = .active(runner, handler)
            self.run(promise: finishedPromise)
            return finishedPromise.futureResult.mapResult { $0 }
        }.flatMap { runnerResult -> EventLoopFuture<Int> in
            // after the lambda finishPromise has succeeded or failed we need to
            // shutdown the handler
            terminator.terminate(eventLoop: self.eventLoop).flatMapErrorThrowing { error in
                // if, we had an error shutting down the handler, we want to concatenate it with
                // the runner result
                logger.error("Error shutting down handler: \(error)")
                throw LambdaRuntimeError.shutdownError(shutdownError: error, runnerResult: runnerResult)
            }.flatMapResult { _ -> Result<Int, Error> in
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

    /// Begin the `LambdaRuntime` shutdown.
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
                runner.run(handler: handler, logger: logger).whenComplete { result in
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
        case active(LambdaRunner, any LambdaRuntimeHandler)
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

public enum LambdaRuntimeFactory {
    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerType: The ``SimpleLambdaHandler`` type the `LambdaRuntime` shall create and manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @inlinable
    public static func makeRuntime<Handler: SimpleLambdaHandler>(
        _ handlerType: Handler.Type,
        eventLoop: any EventLoop,
        logger: Logger
    ) -> LambdaRuntime<some ByteBufferLambdaHandler> {
        LambdaRuntime<CodableSimpleLambdaHandler<Handler>>(
            handlerProvider: CodableSimpleLambdaHandler<Handler>.makeHandler(context:),
            eventLoop: eventLoop,
            logger: logger
        )
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerType: The ``LambdaHandler`` type the `LambdaRuntime` shall create and manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @inlinable
    public static func makeRuntime<Handler: LambdaHandler>(
        _ handlerType: Handler.Type,
        eventLoop: any EventLoop,
        logger: Logger
    ) -> LambdaRuntime<some LambdaRuntimeHandler> {
        LambdaRuntime<CodableLambdaHandler<Handler>>(
            handlerProvider: CodableLambdaHandler<Handler>.makeHandler(context:),
            eventLoop: eventLoop,
            logger: logger
        )
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerType: The ``EventLoopLambdaHandler`` type the `LambdaRuntime` shall create and manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @inlinable
    public static func makeRuntime<Handler: EventLoopLambdaHandler>(
        _ handlerType: Handler.Type,
        eventLoop: any EventLoop,
        logger: Logger
    ) -> LambdaRuntime<some LambdaRuntimeHandler> {
        LambdaRuntime<CodableEventLoopLambdaHandler<Handler>>(
            handlerProvider: CodableEventLoopLambdaHandler<Handler>.makeHandler(context:),
            eventLoop: eventLoop,
            logger: logger
        )
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerType: The ``ByteBufferLambdaHandler`` type the `LambdaRuntime` shall create and manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @inlinable
    public static func makeRuntime<Handler: ByteBufferLambdaHandler>(
        _ handlerType: Handler.Type,
        eventLoop: any EventLoop,
        logger: Logger
    ) -> LambdaRuntime<some LambdaRuntimeHandler> {
        LambdaRuntime<Handler>(
            handlerProvider: Handler.makeHandler(context:),
            eventLoop: eventLoop,
            logger: logger
        )
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerProvider: A provider of the ``Handler`` the `LambdaRuntime` will manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @inlinable
    public static func makeRuntime<Handler: LambdaRuntimeHandler>(
        handlerProvider: @escaping (LambdaInitializationContext) -> EventLoopFuture<Handler>,
        eventLoop: any EventLoop,
        logger: Logger
    ) -> LambdaRuntime<Handler> {
        LambdaRuntime(
            handlerProvider: handlerProvider,
            eventLoop: eventLoop,
            logger: logger
        )
    }

    /// Create a new `LambdaRuntime`.
    ///
    /// - parameters:
    ///     - handlerProvider: A provider of the ``Handler`` the `LambdaRuntime` will manage.
    ///     - eventLoop: An `EventLoop` to run the Lambda on.
    ///     - logger: A `Logger` to log the Lambda events.
    @inlinable
    public static func makeRuntime<Handler: LambdaRuntimeHandler>(
        handlerProvider: @escaping (LambdaInitializationContext) async throws -> Handler,
        eventLoop: any EventLoop,
        logger: Logger
    ) -> LambdaRuntime<Handler> {
        LambdaRuntime(
            handlerProvider: { context in
                let promise = eventLoop.makePromise(of: Handler.self)
                promise.completeWithTask {
                    try await handlerProvider(context)
                }
                return promise.futureResult
            },
            eventLoop: eventLoop,
            logger: logger
        )
    }
}

/// This is safe since lambda runtime synchronizes by dispatching all methods to a single `EventLoop`
extension LambdaRuntime: @unchecked Sendable {}
