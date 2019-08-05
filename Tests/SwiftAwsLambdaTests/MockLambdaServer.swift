//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import NIO
import NIOHTTP1
@testable import SwiftAwsLambda

internal class MockLambdaServer {
    private let logger = Logger(label: "MockLambdaServer")
    private let behavior: LambdaServerBehavior
    private let group: EventLoopGroup
    private var channel: Channel?
    private var shutdown = false

    public init(behavior: LambdaServerBehavior) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.behavior = behavior
    }

    deinit {
        assert(shutdown)
    }

    func start(host: String = Defaults.host, port: Int = Defaults.port) -> EventLoopFuture<MockLambdaServer> {
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                    channel.pipeline.addHandler(HTTPHandler(logger: self.logger, behavior: self.behavior))
                }
            }

            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: false)

        return bootstrap.bind(host: host, port: port).flatMap { channel in
            self.channel = channel
            guard let localAddress = channel.localAddress else {
                return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
            }
            self.logger.info("\(self) started and listening on \(localAddress)")
            return channel.eventLoop.makeSucceededFuture(self)
        }
    }

    func stop() -> EventLoopFuture<Void> {
        self.logger.info("stopping \(self)")
        guard let channel = self.channel else {
            return self.group.next().makeFailedFuture(ServerError.notReady)
        }
        channel.closeFuture.whenComplete { _ in
            self.shutdown = true
            self.logger.info("\(self) stopped")
        }
        channel.close(promise: nil)
        return channel.closeFuture
    }
}

internal final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private let logger: Logger
    private let behavior: LambdaServerBehavior

    private var requestHead: HTTPRequestHead?
    private var requestBody: ByteBuffer?

    public init(logger: Logger, behavior: LambdaServerBehavior) {
        self.logger = logger
        self.behavior = behavior
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case .head(let head):
            self.requestHead = head
            self.requestBody?.clear()
        case .body(var buf):
            if self.requestBody == nil {
                self.requestBody = context.channel.allocator.buffer(capacity: buf.readableBytes)
            }
            self.requestBody?.writeBuffer(&buf)
        case .end:
            self.processRequest(context: context)
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func processRequest(context: ChannelHandlerContext) {
        guard let requestHead = self.requestHead else {
            return self.writeResponse(context: context, version: HTTPVersion(major: 1, minor: 1), status: .badRequest)
        }
        self.logger.info("\(self) processing \(requestHead.uri)")

        let requestBody = self.requestBody.flatMap { (buffer: ByteBuffer) -> String? in
            var buffer = buffer
            return buffer.readString(length: buffer.readableBytes)
        }

        var responseStatus: HTTPResponseStatus
        var responseBody: String?
        var responseHeaders: [(String, String)]?
        if requestHead.uri.hasSuffix(Consts.requestWorkURLSuffix) {
            switch self.behavior.getWork() {
            case .success(let requestId, let result):
                responseStatus = .ok
                responseBody = result
                responseHeaders = [(AmazonHeaders.requestID, requestId)]
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if requestHead.uri.hasSuffix(Consts.postResponseURLSuffix) {
            guard let requestId = requestHead.uri.split(separator: "/").dropFirst(3).first,
                let response = requestBody
            else {
                return self.writeResponse(context: context, version: requestHead.version, status: .badRequest)
            }
            switch self.behavior.processResponse(requestId: String(requestId), response: response) {
            case .success:
                responseStatus = .accepted
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if requestHead.uri.hasSuffix(Consts.postErrorURLSuffix) {
            guard let requestId = requestHead.uri.split(separator: "/").dropFirst(3).first,
                let json = requestBody,
                let error = ErrorResponse.fromJson(json)
            else {
                return self.writeResponse(context: context, version: requestHead.version, status: .badRequest)
            }
            switch self.behavior.processError(requestId: String(requestId), error: error) {
            case .success():
                responseStatus = .accepted
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else {
            responseStatus = .notFound
        }
        self.writeResponse(context: context, version: requestHead.version, status: responseStatus, headers: responseHeaders, body: responseBody)
    }

    func writeResponse(context: ChannelHandlerContext, version: HTTPVersion, status: HTTPResponseStatus, headers: [(String, String)]? = nil, body: String? = nil) {
        var headers = HTTPHeaders(headers ?? [])
        headers.add(name: "Content-Length", value: "\(body?.utf8.count ?? 0)")
        headers.add(name: "Connection", value: "close") // no keep alive
        let head = HTTPResponseHead(version: version, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        if let b = body {
            var buffer = context.channel.allocator.buffer(capacity: b.utf8.count)
            buffer.writeString(b)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            // no keep alive
            context.close(promise: nil)
        }
    }
}

internal protocol LambdaServerBehavior {
    func getWork() -> GetWorkResult
    func processResponse(requestId: String, response: String) -> ProcessResponseResult
    func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult
}

internal typealias GetWorkResult = Result<(String, String), GetWorkError>

internal enum GetWorkError: Int, Error {
    case badRequest = 400
    case tooManyRequests = 429
    case internalServerError = 500
}

internal enum ProcessResponseResult {
    case success
    case failure(ProcessResponseError)
}

internal enum ProcessResponseError: Int {
    case badRequest = 400
    case payloadTooLarge = 413
    case tooManyRequests = 429
    case internalServerError = 500
}

internal typealias ProcessErrorResult = Result<Void, ProcessError>

internal enum ProcessError: Int, Error {
    case invalidErrorShape = 299
    case badRequest = 400
    case internalServerError = 500
}

internal enum ServerError: Error {
    case notReady
    case cantBind
}

private extension ErrorResponse {
    static func fromJson(_ s: String) -> ErrorResponse? {
        let decoder = JSONDecoder()
        do {
            if let data = s.data(using: .utf8) {
                return try decoder.decode(ErrorResponse.self, from: data)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}
