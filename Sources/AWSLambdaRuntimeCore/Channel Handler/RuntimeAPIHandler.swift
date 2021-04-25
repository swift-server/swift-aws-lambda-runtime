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

enum RuntimeAPIRequest: Equatable {
    case next
    case invocationResponse(String, ByteBuffer?)
    case invocationError(String, ErrorResponse)
    case initializationError(ErrorResponse)
}

enum RuntimeAPIResponse: Equatable {
    case next(Invocation, ByteBuffer)
    case accepted
    case error(ErrorResponse)
}

final class RuntimeAPIHandler: ChannelDuplexHandler {
    typealias InboundIn = NIOHTTPClientResponseFull
    typealias InboundOut = RuntimeAPIResponse
    typealias OutboundIn = RuntimeAPIRequest
    typealias OutboundOut = HTTPClientRequestPart

    // prepared header cache, to reduce number of total allocs
    let headers: HTTPHeaders

    let logger: Logger

    init(configuration: Lambda.Configuration.RuntimeEngine, logger: Logger) {
        let host: String
        switch configuration.port {
        case 80:
            host = configuration.ip
        default:
            host = "\(configuration.ip):\(configuration.port)"
        }

        self.logger = logger
        self.headers = HTTPHeaders([
            ("host", "\(host)"),
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

            context.fireChannelRead(wrapInboundOut(.next(invocation, event)))
        case .accepted:
            context.fireChannelRead(wrapInboundOut(.accepted))

        case .badRequest, .forbidden, .payloadTooLarge:
            self.logger.trace("Unexpected http message", metadata: ["http_message": "\(httpResponse)"])
            context.fireChannelRead(wrapInboundOut(.error(.init(errorType: "", errorMessage: ""))))

        default:
            self.logger.trace("Unexpected http message", metadata: ["http_message": "\(httpResponse)"])
            context.fireErrorCaught(Lambda.RuntimeError.badStatusCode(httpResponse.head.status))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        switch self.unwrapOutboundIn(data) {
        case .next:
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .GET,
                uri: "/2018-06-01/runtime/invocation/next",
                headers: self.headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.end(nil)), promise: promise)

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
            context.write(wrapOutboundOut(.end(nil)), promise: promise)

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
            context.write(wrapOutboundOut(.end(nil)), promise: promise)

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
            context.write(wrapOutboundOut(.end(nil)), promise: promise)
        }
    }
}

/// AWS Lambda HTTP Headers, used to populate the `LambdaContext` object.
internal enum AmazonHeaders {
    static let requestID = "Lambda-Runtime-Aws-Request-Id"
    static let traceID = "Lambda-Runtime-Trace-Id"
    static let clientContext = "Lambda-Runtime-Client-Context"
    static let cognitoIdentity = "Lambda-Runtime-Cognito-Identity"
    static let deadline = "Lambda-Runtime-Deadline-Ms"
    static let invokedFunctionARN = "Lambda-Runtime-Invoked-Function-Arn"
}

internal struct ErrorResponse: Codable, Equatable {
    var errorType: String
    var errorMessage: String
}

extension ErrorResponse {
    internal func toJSONBytes() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.append(UInt8(ascii: "{"))
        bytes.append(contentsOf: #""errorType":"#.utf8)
        self.errorType.encodeAsJSONString(into: &bytes)
        bytes.append(contentsOf: #","errorMessage":"#.utf8)
        self.errorMessage.encodeAsJSONString(into: &bytes)
        bytes.append(UInt8(ascii: "}"))
        return bytes
    }
}

internal struct Invocation: Equatable {
    let requestID: String
    let deadlineInMillisSinceEpoch: Int64
    let invokedFunctionARN: String
    let traceID: String
    let clientContext: String?
    let cognitoIdentity: String?

    init(
        requestID: String,
        deadlineInMillisSinceEpoch: Int64,
        invokedFunctionARN: String,
        traceID: String,
        clientContext: String?,
        cognitoIdentity: String?
    ) {
        self.requestID = requestID
        self.deadlineInMillisSinceEpoch = deadlineInMillisSinceEpoch
        self.invokedFunctionARN = invokedFunctionARN
        self.traceID = traceID
        self.clientContext = clientContext
        self.cognitoIdentity = cognitoIdentity
    }
}
