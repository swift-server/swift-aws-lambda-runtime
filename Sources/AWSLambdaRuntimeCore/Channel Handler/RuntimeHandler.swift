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

enum ControlPlaneRequest {
    case next
    case invocationResponse(String, ByteBuffer?)
    case invocationError(String, ErrorResponse)
    case initializationError(ErrorResponse)
}

enum ControlPlaneResponse {
    case next(Lambda.Invocation, ByteBuffer)
    case accepted
    case error(ErrorResponse)
}

final class RuntimeHandler<H: Lambda.Handler>: ChannelDuplexHandler {
    typealias InboundIn = ControlPlaneResponse
    typealias OutboundIn = Never
    typealias OutboundOut = ControlPlaneRequest
    
    var state: StateMachine {
        didSet {
            self.logger.trace("State changed", metadata: [
                "state": "\(self.state)"
            ])
        }
    }
    let logger: Logger
    
    @inlinable
    init(maxTimes: Int, logger: Logger, factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<H>) {
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
        case .getNextInvocation:
            context.write(wrapOutboundOut(.next), promise: nil)
        case .invokeHandler(let handler, let invocation, let bytes):
            let lambdaContext = Lambda.Context(
                logger: self.logger,
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
                context.write(wrapOutboundOut(.invocationResponse(requestID, buffer)), promise: nil)
            case .failure(let error):
                let response = ErrorResponse(errorType: "Unhandeled Error", errorMessage: "\(error)")
                context.write(wrapOutboundOut(.invocationError(requestID, response)), promise: nil)
            }
        case .reportInitializationError(let error):
            let response = ErrorResponse(errorType: "Unhandeled Error", errorMessage: "\(error)")
            context.write(wrapOutboundOut(.initializationError(response)), promise: nil)
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
            case initialized(factory: (Lambda.InitializationContext) -> EventLoopFuture<H>)
            case starting(handler: Result<H, Error>?, connected: Bool)
            case running(H, state: InvocationState)
            case shuttingdown
            case reportInitializationError
            case shutdown
        }

        enum Action {
            case connect(to: SocketAddress, promise: EventLoopPromise<Void>?, andInitializeHandler: (Lambda.InitializationContext) -> EventLoopFuture<H>)
            case getNextInvocation
            case invokeHandler(H, Lambda.Invocation, ByteBuffer)
            case reportInvocationResult(requestID: String, Result<ByteBuffer?, Error>)
            case reportInitializationError(Error)
            case closeConnection
            case fireChannelInactive
            case wait
        }
        
        private var state: State
        private var markShutdown: Bool = false
        private var invocationCount = 0
        private let maxTimes: Int
        
        init(maxTimes: Int, factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<H>) {
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
                self.state = .running(handler, state: .waitingForNextInvocation)
                return .getNextInvocation
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
        
        mutating func handlerInitialized(_ handler: H) -> Action {
            switch self.state {
            case .starting(.none, connected: false):
                self.state = .starting(handler: .success(handler), connected: false)
                return .wait
            case .starting(.none, connected: true):
                self.state = .running(handler, state: .waitingForNextInvocation)
                return .getNextInvocation
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
        
        mutating func nextInvocationReceived(_ invocation: Lambda.Invocation, _ bytes: ByteBuffer) -> Action {
            guard case .running(let handler, .waitingForNextInvocation) = self.state else {
                preconditionFailure()
            }
            
            self.invocationCount += 1
            self.state = .running(handler, state: .runningHandler(requestID: invocation.requestID))
            return .invokeHandler(handler, invocation, bytes)
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
