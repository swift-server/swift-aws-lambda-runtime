//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIO
import Logging

final class RuntimeHandler: ChannelDuplexHandler {
    typealias InboundIn = RuntimeAPIResponse
    typealias OutboundIn = Never
    typealias OutboundOut = RuntimeAPIRequest
    
    var state: StateMachine {
        didSet {
            self.logger.trace("State changed", metadata: [
                "state": "\(self.state)"
            ])
        }
    }
    let logger: Logger
    
    init(maxTimes: Int, logger: Logger, factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>) {
        self.logger = logger
        self.state = StateMachine(maxTimes: maxTimes, factory: factory)
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        precondition(!context.channel.isActive, "Channel must not be active when adding handler")
    }
    
    func connect(context: ChannelHandlerContext, to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        // when we start the connection, we
        
        let action = self.state.connect(to: address, promise: promise)
        self.run(action: action, context: context)
    }
    
    func channelActive(context: ChannelHandlerContext) {
        let action = self.state.connected()
        self.run(action: action, context: context)
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        let action = self.state.channelInactive()
        self.run(action: action, context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        
        switch response {
        case .accepted:
            let action = self.state.acceptedReceived()
            self.run(action: action, context: context)
        case .error(let errorResponse):
            let action = self.state.errorMessageReceived(errorResponse)
            self.run(action: action, context: context)
        case .next(let invocation, let buffer):
            let action = self.state.nextInvocationReceived(invocation, buffer)
            self.run(action: action, context: context)
        }
    }
    
    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        guard case .all = mode else {
            preconditionFailure("Unsupported close mode. Currently only `.all` is supported.")
        }
        
        let action = self.state.close()
        self.run(action: action, context: context)
    }
    
    func run(action: StateMachine.Action, context: ChannelHandlerContext) {
        switch action {
        case .connect(to: let address, let promise, andInitializeHandler: let factory):
            let lambdaContext = Lambda.InitializationContext(
                logger: self.logger,
                eventLoop: context.channel.eventLoop,
                allocator: context.channel.allocator)
            factory(lambdaContext).hop(to: context.eventLoop).whenComplete { result in
                switch result {
                case .success(let handler):
                    let action = self.state.handlerInitialized(handler)
                    self.run(action: action, context: context)
                case .failure(let error):
                    let action = self.state.handlerFailedToInitialize(error)
                    self.run(action: action, context: context)
                }
            }
            
            context.connect(to: address, promise: promise)
        case .reportStartupSuccessful:
            context.fireUserInboundEventTriggered(RuntimeEvent.startupCompleted)
            let action = self.state.startupSuccessReported()
            self.run(action: action, context: context)
        case .reportStartupFailure(let error):
            context.fireErrorCaught(error)
            
        case .getNextInvocation:
            context.writeAndFlush(wrapOutboundOut(.next), promise: nil)
        case .invokeHandler(let handler, let invocation, let bytes, let invocationCount):
            var logger = self.logger
            logger[metadataKey: "lifecycleIteration"] = "\(invocationCount)"
            let lambdaContext = Lambda.Context(
                logger: logger,
                eventLoop: context.eventLoop,
                allocator: context.channel.allocator,
                invocation: invocation)
            handler.handle(context: lambdaContext, event: bytes).hop(to: context.eventLoop).whenComplete {
                let action = self.state.invocationCompleted($0)
                self.run(action: action, context: context)
            }
        case .reportInvocationResult(requestID: let requestID, let result):
            switch result {
            case .success(let buffer):
                context.writeAndFlush(wrapOutboundOut(.invocationResponse(requestID, buffer)), promise: nil)
            case .failure(let error):
                let response = ErrorResponse(errorType: "Unhandeled Error", errorMessage: "\(error)")
                context.writeAndFlush(wrapOutboundOut(.invocationError(requestID, response)), promise: nil)
            }
        case .reportInitializationError(let error):
            let response = ErrorResponse(errorType: "Unhandeled Error", errorMessage: "\(error)")
            context.writeAndFlush(wrapOutboundOut(.initializationError(response)), promise: nil)
        case .closeConnection:
            context.close(mode: .all, promise: nil)
        case .fireChannelInactive:
            context.fireChannelInactive()
        case .wait:
            break
        }
    }
    
}

extension RuntimeHandler {
    
    struct StateMachine {
        enum InvocationState {
            case waitingForNextInvocation
            case runningHandler(requestID: String)
            case reportingResult
        }
        
        enum State {
            case initialized(factory: (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>)
            case starting(handler: Result<ByteBufferLambdaHandler, Error>?, connected: Bool)
            case started(handler: ByteBufferLambdaHandler)
            case running(ByteBufferLambdaHandler, state: InvocationState)
            case shuttingdown
            case reportInitializationError
            case shutdown
        }

        enum Action {
            case connect(to: SocketAddress, promise: EventLoopPromise<Void>?, andInitializeHandler: (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>)
            case reportStartupSuccessful
            case reportStartupFailure(Error)
            case getNextInvocation
            case invokeHandler(ByteBufferLambdaHandler, Lambda.Invocation, ByteBuffer, Int)
            case reportInvocationResult(requestID: String, Result<ByteBuffer?, Error>)
            case reportInitializationError(Error)
            case closeConnection
            case fireChannelInactive
            case wait
        }
        
        private var state: State
        private var markShutdown: Bool = false
        private let maxTimes: Int
        private var invocationCount = 0
        
        init(maxTimes: Int, factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>) {
            self.maxTimes = maxTimes
            self.state = .initialized(factory: factory)
        }
        
        #if DEBUG
        init(state: State, maxTimes: Int) {
            self.state = state
            self.maxTimes = maxTimes
        }
        #endif
        
        mutating func connect(to address: SocketAddress, promise: EventLoopPromise<Void>?) -> Action {
            guard case .initialized(let factory) = self.state else {
                preconditionFailure()
            }
            
            self.state = .starting(handler: nil, connected: false)
            return .connect(to: address, promise: promise, andInitializeHandler: factory)
        }
        
        mutating func connected() -> Action {
            switch self.state {
            case .starting(.some(.success(let handler)), connected: false):
                self.state = .started(handler: handler)
                return .reportStartupSuccessful
            case .starting(.some(.failure(let error)), connected: false):
                self.state = .reportInitializationError
                return .reportInitializationError(error)
            case .starting(.none, connected: false):
                self.state = .starting(handler: .none, connected: true)
                return .wait
            default:
                preconditionFailure()
            }
        }
        
        mutating func handlerInitialized(_ handler: ByteBufferLambdaHandler) -> Action {
            switch self.state {
            case .starting(.none, connected: false):
                self.state = .starting(handler: .success(handler), connected: false)
                return .wait
            case .starting(.none, connected: true):
                self.state = .started(handler: handler)
                return .reportStartupSuccessful
            default:
                preconditionFailure()
            }
        }
        
        mutating func handlerFailedToInitialize(_ error: Error) -> Action {
            switch self.state {
            case .starting(.none, connected: false):
                self.state = .starting(handler: .failure(error), connected: false)
                return .wait
            case .starting(.none, connected: true):
                self.state = .reportInitializationError
                return .reportInitializationError(error)
            default:
                preconditionFailure()
            }
        }
        
        mutating func startupSuccessReported() -> Action {
            guard case .started(let handler) = self.state else {
                preconditionFailure()
            }
            
            self.state = .running(handler, state: .waitingForNextInvocation)
            return .getNextInvocation
        }
        
        mutating func nextInvocationReceived(_ invocation: Lambda.Invocation, _ bytes: ByteBuffer) -> Action {
            guard case .running(let handler, .waitingForNextInvocation) = self.state else {
                preconditionFailure()
            }
            
            self.invocationCount += 1
            self.state = .running(handler, state: .runningHandler(requestID: invocation.requestID))
            return .invokeHandler(handler, invocation, bytes, self.invocationCount)
        }
        
        mutating func invocationCompleted(_ result: Result<ByteBuffer?, Error>) -> Action {
            guard case .running(let handler, .runningHandler(let requestID)) = self.state else {
                preconditionFailure()
            }
            
            self.state = .running(handler, state: .reportingResult)
            return .reportInvocationResult(requestID: requestID, result)
        }
        
        mutating func acceptedReceived() -> Action {
            switch self.state {
            case .running(_, state: .reportingResult) where self.markShutdown == true || (self.maxTimes > 0 && self.invocationCount == self.maxTimes):
                self.state = .shuttingdown
                return .closeConnection
            case .running(let handler, state: .reportingResult):
                self.state = .running(handler, state: .waitingForNextInvocation)
                return .getNextInvocation
            case .reportInitializationError:
                self.state = .shuttingdown
                return .closeConnection
            default:
                preconditionFailure()
            }
        }
        
        mutating func close() -> Action {
            switch self.state {
            case .running(_, state: .waitingForNextInvocation):
                self.state = .shuttingdown
                return .closeConnection
            case .running(_, state: _):
                self.markShutdown = true
                return .wait
            default:
                preconditionFailure()
            }
        }
        
        mutating func channelInactive() -> Action {
            switch self.state {
            case .shuttingdown:
                self.state = .shutdown
                return .fireChannelInactive
            default:
                preconditionFailure()
            }

        }
        
        mutating func errorMessageReceived(_ error: ErrorResponse) -> Action {
            preconditionFailure()
        }
        
        mutating func errorHappened(_ error: Error) -> Action {
            preconditionFailure()
        }
    }
}
