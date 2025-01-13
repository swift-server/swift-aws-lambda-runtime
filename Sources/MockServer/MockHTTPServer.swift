//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOHTTP1
import NIOPosix

// for UUID and Date
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@main
public class MockHttpServer {

    public static func main() throws {
        let server = MockHttpServer()
        try server.start()
    }

    private func start() throws {
        let host = env("HOST") ?? "127.0.0.1"
        let port = env("PORT").flatMap(Int.init) ?? 7000
        let mode = env("MODE").flatMap(Mode.init) ?? .string
        var log = Logger(label: "MockServer")
        log.logLevel = env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info
        let logger = log

        let socketBootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount))
            // Specify backlog and enable SO_REUSEADDR for the server itself
            // .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            // .childChannelOption(.maxMessagesPerRead, value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(HTTPHandler(mode: mode, logger: logger))
                }
            }

        let channel = try socketBootstrap.bind(host: host, port: port).wait()
        logger.debug("Server started and listening on \(host):\(port)")

        // This will never return as we don't close the ServerChannel
        try channel.closeFuture.wait()
    }
}

private final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private enum State {
        case idle
        case waitingForRequestBody
        case sendingResponse

        mutating func requestReceived() {
            precondition(self == .idle, "Invalid state for request received: \(self)")
            self = .waitingForRequestBody
        }

        mutating func requestComplete() {
            precondition(
                self == .waitingForRequestBody,
                "Invalid state for request complete: \(self)"
            )
            self = .sendingResponse
        }

        mutating func responseComplete() {
            precondition(self == .sendingResponse, "Invalid state for response complete: \(self)")
            self = .idle
        }
    }

    private let logger: Logger
    private let mode: Mode

    private var buffer: ByteBuffer! = nil
    private var state: HTTPHandler.State = .idle
    private var keepAlive = false

    private var requestHead: HTTPRequestHead?
    private var requestBodyBytes: Int = 0

    init(mode: Mode, logger: Logger) {
        self.mode = mode
        self.logger = logger
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = Self.unwrapInboundIn(data)
        handle(context: context, request: reqPart)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
        self.buffer.clear()
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 0)
    }

    private func handle(context: ChannelHandlerContext, request: HTTPServerRequestPart) {
        switch request {
        case .head(let request):
            logger.trace("Received request .head")
            self.requestHead = request
            self.requestBodyBytes = 0
            self.keepAlive = request.isKeepAlive
            self.state.requestReceived()
        case .body(buffer: var buf):
            logger.trace("Received request .body")
            self.requestBodyBytes += buf.readableBytes
            self.buffer.writeBuffer(&buf)
        case .end:
            logger.trace("Received request .end")
            self.state.requestComplete()

            precondition(requestHead != nil, "Received .end without .head")
            let (responseStatus, responseHeaders, responseBody) = self.processRequest(
                requestHead: self.requestHead!,
                requestBody: self.buffer
            )

            self.buffer.clear()
            self.buffer.writeString(responseBody)

            var headers = HTTPHeaders(responseHeaders)
            headers.add(name: "Content-Length", value: "\(responseBody.utf8.count)")

            // write the response
            context.write(
                Self.wrapOutboundOut(
                    .head(
                        httpResponseHead(
                            request: self.requestHead!,
                            status: responseStatus,
                            headers: headers
                        )
                    )
                ),
                promise: nil
            )
            context.write(Self.wrapOutboundOut(.body(.byteBuffer(self.buffer))), promise: nil)
            self.completeResponse(context, trailers: nil, promise: nil)
        }
    }

    private func processRequest(
        requestHead: HTTPRequestHead,
        requestBody: ByteBuffer
    ) -> (HTTPResponseStatus, [(String, String)], String) {
        var responseStatus: HTTPResponseStatus = .ok
        var responseBody: String = ""
        var responseHeaders: [(String, String)] = []

        logger.trace(
            "Processing request for : \(requestHead) - \(requestBody.getString(at: 0, length: self.requestBodyBytes) ?? "")"
        )

        if requestHead.uri.hasSuffix("/next") {
            logger.trace("URI /next")

            responseStatus = .accepted

            let requestId = UUID().uuidString
            switch self.mode {
            case .string:
                responseBody = "\"\(requestId)\""  // must be a valid JSON string
            case .json:
                responseBody = "{ \"body\": \"\(requestId)\" }"
            }
            let deadline = Int64(Date(timeIntervalSinceNow: 60).timeIntervalSince1970 * 1000)
            responseHeaders = [
                // ("Connection", "close"),
                (AmazonHeaders.requestID, requestId),
                (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime"),
                (AmazonHeaders.traceID, "Root=1-5bef4de7-ad49b0e87f6ef6c87fc2e700;Parent=9a9197af755a6419;Sampled=1"),
                (AmazonHeaders.deadline, String(deadline)),
            ]
        } else if requestHead.uri.hasSuffix("/response") {
            logger.trace("URI /response")
            responseStatus = .accepted
        } else if requestHead.uri.hasSuffix("/error") {
            logger.trace("URI /error")
            responseStatus = .ok
        } else {
            logger.trace("Unknown URI : \(requestHead)")
            responseStatus = .notFound
        }
        logger.trace("Returning response: \(responseStatus), \(responseHeaders), \(responseBody)")
        return (responseStatus, responseHeaders, responseBody)
    }

    private func completeResponse(
        _ context: ChannelHandlerContext,
        trailers: HTTPHeaders?,
        promise: EventLoopPromise<Void>?
    ) {
        self.state.responseComplete()

        let eventLoop = context.eventLoop
        let loopBoundContext = NIOLoopBound(context, eventLoop: eventLoop)

        let promise = self.keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
        if !self.keepAlive {
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in
                let context = loopBoundContext.value
                context.close(promise: nil)
            }
        }

        context.writeAndFlush(Self.wrapOutboundOut(.end(trailers)), promise: promise)
    }

    private func httpResponseHead(
        request: HTTPRequestHead,
        status: HTTPResponseStatus,
        headers: HTTPHeaders = HTTPHeaders()
    ) -> HTTPResponseHead {
        var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
        let connectionHeaders: [String] = head.headers[canonicalForm: "connection"].map {
            $0.lowercased()
        }

        if !connectionHeaders.contains("keep-alive") && !connectionHeaders.contains("close") {
            // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers

            switch (request.isKeepAlive, request.version.major, request.version.minor) {
            case (true, 1, 0):
                // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
                head.headers.add(name: "Connection", value: "keep-alive")
            case (false, 1, let n) where n >= 1:
                // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
                head.headers.add(name: "Connection", value: "close")
            default:
                // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
                ()
            }
        }
        return head
    }

    private enum ServerError: Error {
        case notReady
        case cantBind
    }

    private enum AmazonHeaders {
        static let requestID = "Lambda-Runtime-Aws-Request-Id"
        static let traceID = "Lambda-Runtime-Trace-Id"
        static let clientContext = "X-Amz-Client-Context"
        static let cognitoIdentity = "X-Amz-Cognito-Identity"
        static let deadline = "Lambda-Runtime-Deadline-Ms"
        static let invokedFunctionARN = "Lambda-Runtime-Invoked-Function-Arn"
    }
}

private enum Mode: String {
    case string
    case json
}

private func env(_ name: String) -> String? {
    guard let value = getenv(name) else {
        return nil
    }
    return String(cString: value)
}
