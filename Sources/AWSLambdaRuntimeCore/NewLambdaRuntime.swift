//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
import NIOPosix
import Backtrace

#if canImport(Glibc)
import Glibc
#endif

/// `LambdaRuntime` manages the Lambda process lifecycle.
///
/// - note: All state changes are dispatched onto the supplied EventLoop.
public final class NewLambdaRuntime<Handler: ByteBufferLambdaHandler> {
    private let eventLoop: EventLoop
    private let shutdownPromise: EventLoopPromise<Void>
    private let logger: Logger
    private let configuration: Lambda.Configuration

    private var state: StateMachine

    init(eventLoop: EventLoop,
         logger: Logger,
         configuration: Lambda.Configuration,
         handlerType: Handler.Type
    ) {
        self.state = StateMachine()
        self.eventLoop = eventLoop
        self.shutdownPromise = eventLoop.makePromise(of: Void.self)
        self.logger = logger
        self.configuration = configuration
    }

    deinit {
        // TODO: Verify is shutdown
    }

    /// The `Lifecycle` shutdown future.
    ///
    /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda lifecycle has fully shutdown.
    public var shutdownFuture: EventLoopFuture<Void> {
        self.shutdownPromise.futureResult
    }
    
    public func start() -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        self.start(promise: promise)
        return promise.futureResult
    }

    /// Start the `LambdaRuntime`.
    ///
    /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda hander has been created and initiliazed, and a first run has been scheduled.
    public func start(promise: EventLoopPromise<Void>?) {
        if self.eventLoop.inEventLoop {
            self.start0(promise: promise)
        } else {
            self.eventLoop.execute {
                self.start0(promise: promise)
            }
        }
    }
    
    public func __testOnly_start(channel: Channel, promise: EventLoopPromise<Void>?) {
        precondition(channel.eventLoop === self.eventLoop, "Channel must be created on the supplied EventLoop.")
        if self.eventLoop.inEventLoop {
            self.__testOnly_start0(channel: channel, promise: promise)
        } else {
            self.eventLoop.execute {
                self.__testOnly_start0(channel: channel, promise: promise)
            }
        }
    }
    
    /// Begin the `LambdaRuntime` shutdown. Only needed for debugging purposes, hence behind a `DEBUG` flag.
    public func shutdown(promise: EventLoopPromise<Void>?) {
        if self.eventLoop.inEventLoop {
            self.shutdown0(promise: promise)
        } else {
            self.eventLoop.execute {
                self.shutdown0(promise: promise)
            }
        }
    }
    
    // MARK: -  Private -
    
    private func start0(promise: EventLoopPromise<Void>?) {
        self.eventLoop.assertInEventLoop()

        // when starting we want to do thing in parallel:
        //  1. start the connection to the control plane
        //  2. create the lambda handler
        
        self.logger.debug("initializing lambda")
        
        let action = self.state.start(connection: nil, promise: promise)
        self.run(action)
    }
    
    private func shutdown0(promise: EventLoopPromise<Void>?) {
        
    }
    
    private func __testOnly_start0(channel: Channel, promise: EventLoopPromise<Void>?) {
        channel.eventLoop.preconditionInEventLoop()
        assert(channel.isActive)
        
        do {
            let connection = try self.setupConnection(channel: channel)
            let action = self.state.start(connection: connection, promise: promise)
            self.run(action)
        } catch {
            promise?.fail(error)
        }
    }
    
    private func run(_ action: StateMachine.Action) {
        switch action {
        case .createHandler(andConnection: let andConnection):
            self.createHandler()
            if andConnection {
                self.createConnection()
            }
            
        case .invokeHandler(let handler, let invocation, let event):
            self.logger.trace("invoking handler")
            let context = LambdaContext(
                logger: self.logger,
                eventLoop: self.eventLoop,
                allocator: .init(),
                invocation: invocation
            )
            handler.handle(event, context: context).whenComplete { result in
                let action = self.state.invocationFinished(result)
                self.run(action)
            }
            
        case .failRuntime(let error):
            self.shutdownPromise.fail(error)
            
        case .requestNextInvocation(let handler, let startPromise):
            self.logger.trace("requesting next invocation")
            handler.sendRequest(.next)
            startPromise?.succeed(())
            
        case .reportInvocationResult(let requestID, let result, let pipelineNextInvocationRequest, let handler):
            switch result {
            case .success(let body):
                self.logger.trace("reporting invocation success", metadata: [
                    "lambda-request-id": "\(requestID)"
                ])
                handler.sendRequest(.invocationResponse(requestID, body))
                
            case .failure(let error):
                self.logger.trace("reporting invocation failure", metadata: [
                    "lambda-request-id": "\(requestID)"
                ])
                let errorString = String(describing: error)
                let errorResponse = ErrorResponse(errorType: errorString, errorMessage: errorString)
                handler.sendRequest(.invocationError(requestID, errorResponse))
            }
            
            if pipelineNextInvocationRequest {
                handler.sendRequest(.next)
            }
            
        case .reportStartupError(let error, let handler):
            let errorString = String(describing: error)
            handler.sendRequest(.initializationError(.init(errorType: errorString, errorMessage: errorString)))
            
        case .none:
            break
        
        }
    }
    
    private func createConnection() {
        let connectFuture = ClientBootstrap(group: self.eventLoop).connect(
            host: self.configuration.runtimeEngine.ip,
            port: self.configuration.runtimeEngine.port
        )

        connectFuture.whenComplete { result in
            let action: StateMachine.Action
            switch result {
            case .success(let channel):
                do {
                    let connection = try self.setupConnection(channel: channel)
                    action = self.state.httpConnectionCreated(connection)
                } catch {
                    action = self.state.httpChannelConnectFailed(error)
                }
            case .failure(let error):
                action = self.state.httpChannelConnectFailed(error)
            }
            self.run(action)
        }
    }
    
    private func setupConnection(channel: Channel) throws -> Connection {
        let handler = NewLambdaChannelHandler(delegate: self, host: self.configuration.runtimeEngine.ip)
        try channel.pipeline.syncOperations.addHandler(handler)
        return Connection(channel: channel, handler: handler)
    }
    
    private func createHandler() {
        let context = Lambda.InitializationContext(
            logger: self.logger,
            eventLoop: self.eventLoop,
            allocator: ByteBufferAllocator()
        )
        
        Handler.makeHandler(context: context).hop(to: self.eventLoop).whenComplete { result in
            let action: StateMachine.Action
            switch result {
            case .success(let handler):
                action = self.state.handlerCreated(handler)
            case .failure(let error):
                action = self.state.handlerCreationFailed(error)
            }
            self.run(action)
        }
    }
}

extension NewLambdaRuntime: LambdaChannelHandlerDelegate {
    func responseReceived(_ response: ControlPlaneResponse) {
        let action: StateMachine.Action
        switch response {
        case .next(let invocation, let byteBuffer):
            action = self.state.newInvocationReceived(invocation, byteBuffer)

        case .accepted:
            action = self.state.acceptedReceived()

        case .error(let errorResponse):
            action = self.state.errorResponseReceived(errorResponse)
        }
        
        self.run(action)
    }
    
    func errorCaught(_ error: Error) {
        self.state.handlerError(error)
    }
    
    func channelInactive() {
        self.state.channelInactive()
    }
}

extension NewLambdaRuntime {
    
    static func run(handlerType: Handler.Type) {
        Backtrace.install()
        
        let configuration = Lambda.Configuration()
        var logger = Logger(label: "Lambda")
        logger.logLevel = configuration.general.logLevel

        MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { eventLoop in
            let runtime = NewLambdaRuntime(
                eventLoop: eventLoop,
                logger: logger,
                configuration: configuration,
                handlerType: Handler.self
            )

            logger.info("lambda runtime starting with \(configuration)")
            
            #if DEBUG
            let signalSource = trap(signal: configuration.lifecycle.stopSignal) { signal in
                logger.info("intercepted signal: \(signal)")
                runtime.shutdown(promise: nil)
            }
            #endif
            
            runtime.start().flatMap {
                runtime.shutdownFuture
            }.whenComplete { lifecycleResult in
                #if DEBUG
                signalSource.cancel()
                #endif
                eventLoop.shutdownGracefully { error in
                    if let error = error {
                        preconditionFailure("Failed to shutdown eventloop: \(error)")
                    }
                    logger.info("shutdown completed")
                }
            }
        }
    }
}
