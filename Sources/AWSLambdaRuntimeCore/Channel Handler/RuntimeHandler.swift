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

protocol APIRequestWriter {

    mutating func writeRequest(_ request: APIRequest, context: ChannelHandlerContext)
    
    mutating func writerAdded(context: ChannelHandlerContext)
    
    mutating func writerRemoved(context: ChannelHandlerContext)
}

final class RuntimeHandler<Writer: APIRequestWriter>: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundIn = Never
    typealias OutboundOut = ByteBuffer

    var state: StateMachine {
        didSet {
            self.logger.trace("State changed", metadata: [
                "state": "\(self.state)",
            ])
        }
    }
    
    private var writer: Writer
    let logger: Logger

    init(
        configuration: Lambda.Configuration,
        logger: Logger,
        writer: Writer,
        factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>
    ) {
        self.logger = logger
        let maxTimes = configuration.lifecycle.maxTimes
        self.writer = writer
        self.state = StateMachine(maxTimes: maxTimes, factory: factory)
        


        
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.writer.writerAdded(context: context)
        precondition(!context.channel.isActive, "Channel must not be active when adding handler")
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        self.writer.writerRemoved(context: context)
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
            self.writer.writeRequest(.next, context: context)
            
        case .invokeHandler(let handler, let invocation, let bytes, let invocationCount):
            let lambdaContext = Lambda.Context(
                logger: self.logger,
                eventLoop: context.eventLoop,
                allocator: context.channel.allocator,
                invocation: invocation,
                invocationCount: invocationCount
            )
            handler.handle(event: bytes, context: lambdaContext).hop(to: context.eventLoop).whenComplete {
                let action = self.state.invocationCompleted($0)
                self.run(action: action, context: context)
            }
            
        case .reportInvocationResult(requestID: let requestID, let result):
            switch result {
            case .success(let buffer):
                self.writer.writeRequest(.invocationResponse(requestID, buffer), context: context)
                
            case .failure(let error):
                let response = ErrorResponse(errorType: "Unhandled Error", errorMessage: "\(error)")
                self.writer.writeRequest(.invocationError(requestID, response), context: context)
            }
            
        case .reportInitializationError(let error):
            let response = ErrorResponse(errorType: "Unhandled Error", errorMessage: "\(error)")
            self.writer.writeRequest(.initializationError(response), context: context)
            
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

        do {
            let response = try self.parseResponse(httpResponse)
            self.readResponse(response, context: context)
        } catch {
            let action = self.state.errorHappened(error)
            self.run(action: action, context: context)
        }
    }
    
    private func parseResponse(_ httpResponse: NIOHTTPClientResponseFull) throws -> APIResponse {
        switch httpResponse.head.status {
        case .ok:
            let headers = httpResponse.head.headers
            guard let requestID = headers.first(name: AmazonHeaders.requestID), !requestID.isEmpty else {
                throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.requestID)
            }

            guard let deadline = headers.first(name: AmazonHeaders.deadline),
                  let unixTimeInMilliseconds = Int64(deadline)
            else {
                throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.deadline)
            }

            guard let invokedFunctionARN = headers.first(name: AmazonHeaders.invokedFunctionARN) else {
                throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.invokedFunctionARN)
            }

            guard let traceID = headers.first(name: AmazonHeaders.traceID) else {
                throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.traceID)
            }
            
            guard let event = httpResponse.body else {
                throw Lambda.RuntimeError.noBody
            }

            let invocation = Invocation(
                requestID: requestID,
                deadlineInMillisSinceEpoch: unixTimeInMilliseconds,
                invokedFunctionARN: invokedFunctionARN,
                traceID: traceID,
                clientContext: headers.first(name: AmazonHeaders.clientContext),
                cognitoIdentity: headers.first(name: AmazonHeaders.cognitoIdentity)
            )

            return .next(invocation, event)
            
        case .accepted:
            return .accepted

        case .badRequest, .forbidden, .payloadTooLarge:
            self.logger.trace("Unexpected http message", metadata: ["http_message": "\(httpResponse)"])
            return .error(.init(errorType: "", errorMessage: ""))

        default:
            self.logger.trace("Unexpected http message", metadata: ["http_message": "\(httpResponse)"])
            throw Lambda.RuntimeError.badStatusCode(httpResponse.head.status)
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
}
