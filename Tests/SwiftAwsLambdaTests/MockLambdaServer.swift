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

import Foundation // for JSON
import Logging
import NIO
import NIOHTTP1
@testable import SwiftAwsLambda

internal final class MockLambdaServer {
    private let logger = Logger(label: "MockLambdaServer")
    private let behavior: LambdaServerBehavior
    private let host: String
    private let port: Int
    private let keepAlive: Bool
    private let group: EventLoopGroup

    private var channel: Channel?
    private var shutdown = false

    public init(behavior: LambdaServerBehavior, host: String = "127.0.0.1", port: Int = 7000, keepAlive: Bool = true) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.behavior = behavior
        self.host = host
        self.port = port
        self.keepAlive = keepAlive
    }

    deinit {
        assert(shutdown)
    }

    func start() -> EventLoopFuture<MockLambdaServer> {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                    channel.pipeline.addHandler(HTTPHandler(logger: self.logger, keepAlive: self.keepAlive, behavior: self.behavior))
                }
            }
        return bootstrap.bind(host: self.host, port: self.port).flatMap { channel in
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
        return channel.close().always { _ in
            self.shutdown = true
            self.logger.info("\(self) stopped")
        }
    }
}

internal final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private let logger: Logger
    private let keepAlive: Bool
    private let behavior: LambdaServerBehavior

    private var requestHead: HTTPRequestHead!
    private var requestBody: ByteBuffer?

    public init(logger: Logger, keepAlive: Bool, behavior: LambdaServerBehavior) {
        self.logger = logger
        self.keepAlive = keepAlive
        self.behavior = behavior
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case .head(let head):
            self.requestHead = head
            self.requestBody?.clear()
        case .body(var buffer):
            if self.requestBody == nil {
                self.requestBody = buffer
            } else {
                self.requestBody!.writeBuffer(&buffer)
            }
        case .end:
            self.processRequest(context: context)
        }
    }

    func processRequest(context: ChannelHandlerContext) {
        self.logger.info("\(self) processing \(self.requestHead.uri)")

        let requestBody = self.requestBody.flatMap { (buffer: ByteBuffer) -> String? in
            var buffer = buffer
            return buffer.readString(length: buffer.readableBytes)
        }

        var responseStatus: HTTPResponseStatus
        var responseBody: String?
        var responseHeaders: [(String, String)]?

        // Handle post-init-error first to avoid matching the less specific post-error suffix.
        if self.requestHead.uri.hasSuffix(Consts.postInitErrorURL) {
            guard let json = requestBody, let error = ErrorResponse.fromJson(json) else {
                return self.writeResponse(context: context, status: .badRequest)
            }
            switch self.behavior.processInitError(error: error) {
            case .success:
                responseStatus = .accepted
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if self.requestHead.uri.hasSuffix(Consts.requestWorkURLSuffix) {
            switch self.behavior.getWork() {
            case .success(let (requestId, result)):
                if requestId == "timeout" {
                    usleep((UInt32(result) ?? 0) * 1000)
                } else if requestId == "disconnect" {
                    return context.close(promise: nil)
                }
                responseStatus = .ok
                responseBody = result
                responseHeaders = [(AmazonHeaders.requestID, requestId)]
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if self.requestHead.uri.hasSuffix(Consts.postResponseURLSuffix) {
            guard let requestId = requestHead.uri.split(separator: "/").dropFirst(3).first, let response = requestBody else {
                return self.writeResponse(context: context, status: .badRequest)
            }
            switch self.behavior.processResponse(requestId: String(requestId), response: response) {
            case .success:
                responseStatus = .accepted
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if self.requestHead.uri.hasSuffix(Consts.postErrorURLSuffix) {
            guard let requestId = requestHead.uri.split(separator: "/").dropFirst(3).first,
                let json = requestBody,
                let error = ErrorResponse.fromJson(json)
            else {
                return self.writeResponse(context: context, status: .badRequest)
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
        self.writeResponse(context: context, status: responseStatus, headers: responseHeaders, body: responseBody)
    }

    func writeResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, headers: [(String, String)]? = nil, body: String? = nil) {
        var headers = HTTPHeaders(headers ?? [])
        headers.add(name: "Content-Length", value: "\(body?.utf8.count ?? 0)")
        headers.add(name: "Connection", value: self.keepAlive ? "keep-alive" : "close")
        let head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: status, headers: headers)

        context.write(wrapOutboundOut(.head(head))).whenFailure { error in
            self.logger.error("\(self) write error \(error)")
        }

        if let b = body {
            var buffer = context.channel.allocator.buffer(capacity: b.utf8.count)
            buffer.writeString(b)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer)))).whenFailure { error in
                self.logger.error("\(self) write error \(error)")
            }
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
            if case .failure(let error) = result {
                self.logger.error("\(self) write error \(error)")
            }
            if !self.self.keepAlive {
                context.close().whenFailure { error in
                    self.logger.error("\(self) close error \(error)")
                }
            }
        }
    }
}

internal protocol LambdaServerBehavior {
    func getWork() -> GetWorkResult
    func processResponse(requestId: String, response: String) -> ProcessResponseResult
    func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult
    func processInitError(error: ErrorResponse) -> ProcessInitErrorResult
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

internal typealias ProcessInitErrorResult = Result<Void, ProcessError>

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
