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

import Logging
import NIO
import NIOHTTP1

final class RuntimeHandler: ChannelDuplexHandler {
    typealias InboundIn = NIOHTTPClientResponseFull
    typealias OutboundIn = Never
    typealias OutboundOut = HTTPClientRequestPart

    var state: StateMachine {
        didSet {
            self.logger.trace("State changed", metadata: [
                "state": "\(self.state)",
            ])
        }
    }

    let logger: Logger
    let headers: HTTPHeaders

    init(
        configuration: Lambda.Configuration,
        logger: Logger,
        factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>
    ) {
        self.logger = logger
        let maxTimes = configuration.lifecycle.maxTimes
        self.state = StateMachine(maxTimes: maxTimes, factory: factory)
        
        let host: String
        switch configuration.runtimeEngine.port {
        case 80:
            host = configuration.runtimeEngine.ip
        default:
            host = "\(configuration.runtimeEngine.ip):\(configuration.runtimeEngine.port)"
        }

        self.headers = HTTPHeaders([
            ("host", "\(host)"),
            ("user-agent", "Swift-Lambda/Unknown"),
        ])
    }

    func handlerAdded(context: ChannelHandlerContext) {
        precondition(!context.channel.isActive, "Channel must not be active when adding handler")
    }

    func connect(context: ChannelHandlerContext, to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        let action = self.state.connect(to: address, promise: promise)
        self.run(action: action, context: context)
    }

    func channelActive(context: ChannelHandlerContext) {
        self.logger.trace("Channel active")
        
        let action = self.state.connected()
        self.run(action: action, context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        self.logger.trace("Channel inactive")
        
        let action = self.state.channelInactive()
        self.run(action: action, context: context)
    }

    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        self.logger.trace("Outbound close channel received")
        
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
                allocator: context.channel.allocator
            )
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
            
        case .reportStartupSuccessToChannel:
            context.fireUserInboundEventTriggered(RuntimeEvent.startupCompleted)
            let action = self.state.startupSuccessToChannelReported()
            self.run(action: action, context: context)
            
        case .reportStartupFailureToChannel(let error):
            context.fireErrorCaught(error)
            let action = self.state.startupFailureToChannelReported()
            self.run(action: action, context: context)

        case .getNextInvocation:
            self.writeRequest(.next, context: context)
            
        case .invokeHandler(let handler, let invocation, let bytes, let invocationCount):
            let lambdaContext = Lambda.Context(
                logger: self.logger,
                eventLoop: context.eventLoop,
                allocator: context.channel.allocator,
                invocation: invocation,
                invocationCount: invocationCount
            )
            handler.handle(context: lambdaContext, event: bytes).hop(to: context.eventLoop).whenComplete {
                let action = self.state.invocationCompleted($0)
                self.run(action: action, context: context)
            }
            
        case .reportInvocationResult(requestID: let requestID, let result):
            switch result {
            case .success(let buffer):
                self.writeRequest(.invocationResponse(requestID, buffer), context: context)
                
            case .failure(let error):
                let response = ErrorResponse(errorType: "Unhandled Error", errorMessage: "\(error)")
                self.writeRequest(.invocationError(requestID, response), context: context)
            }
            
        case .reportInitializationError(let error):
            let response = ErrorResponse(errorType: "Unhandled Error", errorMessage: "\(error)")
            self.writeRequest(.initializationError(response), context: context)
            
        case .closeConnection:
            context.close(mode: .all, promise: nil)
            
        case .fireChannelInactive:
            context.fireChannelInactive()
            
        case .wait:
            break
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let httpResponse = unwrapInboundIn(data)

        switch httpResponse.head.status {
        case .ok:
            let headers = httpResponse.head.headers
            guard let requestID = headers.first(name: AmazonHeaders.requestID), !requestID.isEmpty else {
                return context.fireErrorCaught(Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.requestID))
            }

            guard let deadline = headers.first(name: AmazonHeaders.deadline),
                  let unixTimeInMilliseconds = Int64(deadline)
            else {
                return context.fireErrorCaught(Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.deadline))
            }

            guard let invokedFunctionARN = headers.first(name: AmazonHeaders.invokedFunctionARN) else {
                return context.fireErrorCaught(Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.invokedFunctionARN))
            }

            guard let traceID = headers.first(name: AmazonHeaders.traceID) else {
                return context.fireErrorCaught(Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.traceID))
            }

            let invocation = Invocation(
                requestID: requestID,
                deadlineInMillisSinceEpoch: unixTimeInMilliseconds,
                invokedFunctionARN: invokedFunctionARN,
                traceID: traceID,
                clientContext: headers.first(name: AmazonHeaders.clientContext),
                cognitoIdentity: headers.first(name: AmazonHeaders.cognitoIdentity)
            )

            guard let event = httpResponse.body else {
                return context.fireErrorCaught(Lambda.RuntimeError.noBody)
            }
            self.readResponse(.next(invocation, event), context: context)
            
        case .accepted:
            self.readResponse(.accepted, context: context)

        case .badRequest, .forbidden, .payloadTooLarge:
            self.logger.trace("Unexpected http message", metadata: ["http_message": "\(httpResponse)"])
            self.readResponse(.error(.init(errorType: "", errorMessage: "")), context: context)

        default:
            self.logger.trace("Unexpected http message", metadata: ["http_message": "\(httpResponse)"])
            context.fireErrorCaught(Lambda.RuntimeError.badStatusCode(httpResponse.head.status))
        }
    }
    
    func readResponse(_ response: APIResponse, context: ChannelHandlerContext) {
        self.logger.trace("Channel read", metadata: ["message": "\(response)"])
        
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

    func writeRequest(_ request: APIRequest, context: ChannelHandlerContext) {
        switch request {
        case .next:
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .GET,
                uri: "/2018-06-01/runtime/invocation/next",
                headers: self.headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.end(nil)), promise: nil)
            context.flush()

        case .invocationResponse(let requestID, let payload):
            var headers = self.headers
            headers.add(name: "content-length", value: "\(payload?.readableBytes ?? 0)")
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: "/2018-06-01/runtime/invocation/\(requestID)/response",
                headers: headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            if let payload = payload {
                context.write(wrapOutboundOut(.body(.byteBuffer(payload))), promise: nil)
            }
            context.write(wrapOutboundOut(.end(nil)), promise: nil)
            context.flush()

        case .invocationError(let requestID, let errorMessage):
            let payload = errorMessage.toJSONBytes()
            var headers = self.headers
            headers.add(name: "content-length", value: "\(payload.count)")
            headers.add(name: "lambda-runtime-function-error-type", value: "Unhandled")
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: "/2018-06-01/runtime/invocation/\(requestID)/error",
                headers: headers
            )
            let buffer = context.channel.allocator.buffer(bytes: payload)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.write(wrapOutboundOut(.end(nil)), promise: nil)
            context.flush()

        case .initializationError(let errorMessage):
            let payload = errorMessage.toJSONBytes()
            var headers = self.headers
            headers.add(name: "content-length", value: "\(payload.count)")
            headers.add(name: "lambda-runtime-function-error-type", value: "Unhandled")
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: "/2018-06-01/runtime/init/error",
                headers: headers
            )
            let buffer = context.channel.allocator.buffer(bytes: payload)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.write(wrapOutboundOut(.end(nil)), promise: nil)
            context.flush()
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
            case shuttingDown
            case reportingInitializationError(Error)
            case reportingInitializationErrorToChannel(Error)
            case shutdown
        }

        enum Action {
            case connect(to: SocketAddress, promise: EventLoopPromise<Void>?, andInitializeHandler: (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>)
            case reportStartupSuccessToChannel
            case reportStartupFailureToChannel(Error)
            case getNextInvocation
            case invokeHandler(ByteBufferLambdaHandler, Invocation, ByteBuffer, Int)
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
                return .reportStartupSuccessToChannel
            case .starting(.some(.failure(let error)), connected: false):
                self.state = .reportingInitializationError(error)
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
                return .reportStartupSuccessToChannel
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
                self.state = .reportingInitializationError(error)
                return .reportInitializationError(error)
            default:
                preconditionFailure()
            }
        }

        mutating func startupSuccessToChannelReported() -> Action {
            guard case .started(let handler) = self.state else {
                preconditionFailure()
            }

            self.state = .running(handler, state: .waitingForNextInvocation)
            return .getNextInvocation
        }

        mutating func startupFailureToChannelReported() -> Action {
            guard case .reportingInitializationErrorToChannel = self.state else {
                preconditionFailure()
            }

            self.state = .shuttingDown
            return .closeConnection
        }

        mutating func nextInvocationReceived(_ invocation: Invocation, _ bytes: ByteBuffer) -> Action {
            guard case .running(let handler, .waitingForNextInvocation) = self.state else {
                preconditionFailure()
            }

            self.invocationCount += 1
            self.state = .running(handler, state: .runningHandler(requestID: invocation.requestID))
            return .invokeHandler(handler, invocation, bytes, self.invocationCount)
        }

        mutating func invocationCompleted(_ result: Result<ByteBuffer?, Error>) -> Action {
            guard case .running(let handler, .runningHandler(let requestID)) = self.state else {
                preconditionFailure("Invalid state: \(self.state)")
            }

            self.state = .running(handler, state: .reportingResult)
            return .reportInvocationResult(requestID: requestID, result)
        }

        mutating func acceptedReceived() -> Action {
            switch self.state {
            case .running(_, state: .reportingResult) where self.markShutdown == true || (self.maxTimes > 0 && self.invocationCount == self.maxTimes):
                self.state = .shuttingDown
                return .closeConnection
                
            case .running(let handler, state: .reportingResult):
                self.state = .running(handler, state: .waitingForNextInvocation)
                return .getNextInvocation
                
            case .reportingInitializationError(let error):
                self.state = .reportingInitializationErrorToChannel(error)
                return .reportStartupFailureToChannel(error)
            
            case .initialized,
                 .starting,
                 .started,
                 .reportingInitializationErrorToChannel,
                 .running(_, state: .waitingForNextInvocation),
                 .running(_, state: .runningHandler),
                 .shuttingDown,
                 .shutdown:
                preconditionFailure("Invalid state: \(self.state)")
            }
        }

        mutating func close() -> Action {
            switch self.state {
            case .running(_, state: .waitingForNextInvocation):
                self.state = .shuttingDown
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
            case .shuttingDown:
                self.state = .shutdown
                return .fireChannelInactive
            case .initialized, .shutdown, .starting(_, connected: false):
                preconditionFailure("Invalid state: \(self.state)")
            case .starting(_, connected: true):
                preconditionFailure("Todo: Unexpected connection closure during startup")
            case .started:
                preconditionFailure("Todo: Unexpected connection closure during startup")
            case .running(_, state: .waitingForNextInvocation):
                self.state = .shutdown
                return .fireChannelInactive
            case .running(_, state: .runningHandler):
                preconditionFailure("Todo: Unexpected connection closure")
            case .running(_, state: .reportingResult):
                preconditionFailure("Todo: Unexpected connection closure")
            case .reportingInitializationError:
                preconditionFailure("Todo: Unexpected connection closure during startup")
            case .reportingInitializationErrorToChannel(_):
                self.state = .shutdown
                return .fireChannelInactive

            }
        }

        mutating func errorMessageReceived(_: ErrorResponse) -> Action {
            preconditionFailure()
        }

        mutating func errorHappened(_: Error) -> Action {
            preconditionFailure()
        }
    }
}
