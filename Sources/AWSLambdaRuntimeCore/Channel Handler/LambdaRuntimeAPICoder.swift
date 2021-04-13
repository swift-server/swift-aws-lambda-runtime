//
//  File.swift
//  
//
//  Created by Fabian Fett on 13.04.21.
//

import NIO
import NIOHTTP1

class LambdaRuntimeAPICoder: ChannelDuplexHandler {
    typealias InboundIn = NIOHTTPClientResponseFull
    typealias InboundOut = ControlPlaneResponse
    typealias OutboundIn = ControlPlaneRequest
    typealias OutboundOut = HTTPClientRequestPart
    
    // prepared header cache, to reduce number of total allocs
    let headers: HTTPHeaders
    
    init(host: String) {
        self.headers = HTTPHeaders([
            ("host", host),
            ("user-agent", "Swift-Lambda/Unknown"),
        ])
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
            
            let invocation = Lambda.Invocation(
                requestID: requestID,
                deadlineInMillisSinceEpoch: unixTimeInMilliseconds,
                invokedFunctionARN: invokedFunctionARN,
                traceID: traceID,
                clientContext: headers["Lambda-Runtime-Client-Context"].first,
                cognitoIdentity: headers["Lambda-Runtime-Cognito-Identity"].first
            )
            
            guard let event = httpResponse.body else {
                return context.fireErrorCaught(Lambda.RuntimeError.noBody)
            }
            
            context.fireChannelRead(wrapInboundOut(.next(invocation, event)))
        case .accepted:
            context.fireChannelRead(wrapInboundOut(.accepted))
            
        case .badRequest, .forbidden, .payloadTooLarge:
            context.fireChannelRead(wrapInboundOut(.error(.init(errorType: "", errorMessage: ""))))
            
        default:
            context.fireErrorCaught(Lambda.RuntimeError.badStatusCode(httpResponse.head.status))
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        switch unwrapOutboundIn(data) {
        case .next:
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .GET,
                uri: "/2018-06-01/runtime/invocation/next",
                headers: self.headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
            
        case .invocationResponse(let requestID, let payload):
            var headers = self.headers
            headers.add(name: "content-length", value: "\(payload?.readableBytes ?? 0)")
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: "/2018-06-01/runtime/\(requestID)/response",
                headers: self.headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            if let payload = payload {
                context.write(wrapOutboundOut(.body(.byteBuffer(payload))), promise: nil)
            }
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
            
        case .invocationError(let requestID, let errorMessage):
            let payload = errorMessage.toJSONBytes()
            var headers = self.headers
            headers.add(name: "content-length", value: "\(payload.count)")
            headers.add(name: "lambda-runtime-function-error-type", value: "Unhandled")
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: "/2018-06-01/runtime/\(requestID)/error",
                headers: self.headers
            )
            let buffer = context.channel.allocator.buffer(bytes: payload)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)

        case .initializationError(let errorMessage):
            let payload = errorMessage.toJSONBytes()
            var headers = self.headers
            headers.add(name: "content-length", value: "\(payload.count)")
            headers.add(name: "lambda-runtime-function-error-type", value: "Unhandled")
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: "/2018-06-01/runtime/init/error",
                headers: self.headers
            )
            let buffer = context.channel.allocator.buffer(bytes: payload)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
        }
    }
}
