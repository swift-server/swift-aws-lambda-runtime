//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation  // for JSON
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix

@testable import AWSLambdaRuntimeCore

func withMockServer<Result>(
    behaviour: some LambdaServerBehavior,
    port: Int = 0,
    keepAlive: Bool = true,
    _ body: (_ port: Int) async throws -> Result
) async throws -> Result {
    let eventLoopGroup = NIOSingletons.posixEventLoopGroup
    let server = MockLambdaServer(behavior: behaviour, port: port, keepAlive: keepAlive, eventLoopGroup: eventLoopGroup)
    let port = try await server.start().get()

    let result: Swift.Result<Result, any Error>
    do {
        result = .success(try await body(port))
    } catch {
        result = .failure(error)
    }

    try? await server.stop().get()
    return try result.get()
}

final class MockLambdaServer {
    private let logger = Logger(label: "MockLambdaServer")
    private let behavior: LambdaServerBehavior
    private let host: String
    private let port: Int
    private let keepAlive: Bool
    private let group: EventLoopGroup

    private var channel: Channel?
    private var shutdown = false

    init(
        behavior: LambdaServerBehavior,
        host: String = "127.0.0.1",
        port: Int = 7000,
        keepAlive: Bool = true,
        eventLoopGroup: MultiThreadedEventLoopGroup
    ) {
        self.group = NIOSingletons.posixEventLoopGroup
        self.behavior = behavior
        self.host = host
        self.port = port
        self.keepAlive = keepAlive
    }

    deinit {
        assert(shutdown)
    }

    func start() -> EventLoopFuture<Int> {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                do {
                    try channel.pipeline.syncOperations.configureHTTPServerPipeline(withErrorHandling: true)
                    try channel.pipeline.syncOperations.addHandler(
                        HTTPHandler(logger: self.logger, keepAlive: self.keepAlive, behavior: self.behavior)
                    )
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
        return bootstrap.bind(host: self.host, port: self.port).flatMap { channel in
            self.channel = channel
            guard let localAddress = channel.localAddress else {
                return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
            }
            self.logger.info("\(self) started and listening on \(localAddress)")
            return channel.eventLoop.makeSucceededFuture(localAddress.port!)
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

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let logger: Logger
    private let keepAlive: Bool
    private let behavior: LambdaServerBehavior

    private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

    init(logger: Logger, keepAlive: Bool, behavior: LambdaServerBehavior) {
        self.logger = logger
        self.keepAlive = keepAlive
        self.behavior = behavior
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case .head(let head):
            self.pending.append((head: head, body: nil))
        case .body(var buffer):
            var request = self.pending.removeFirst()
            if request.body == nil {
                request.body = buffer
            } else {
                request.body!.writeBuffer(&buffer)
            }
            self.pending.prepend(request)
        case .end:
            let request = self.pending.removeFirst()
            self.processRequest(context: context, request: request)
        }
    }

    func processRequest(context: ChannelHandlerContext, request: (head: HTTPRequestHead, body: ByteBuffer?)) {
        self.logger.info("\(self) processing \(request.head.uri)")

        let requestBody = request.body.flatMap { (buffer: ByteBuffer) -> String? in
            var buffer = buffer
            return buffer.readString(length: buffer.readableBytes)
        }

        var responseStatus: HTTPResponseStatus
        var responseBody: String?
        var responseHeaders: [(String, String)]?

        // Handle post-init-error first to avoid matching the less specific post-error suffix.
        if request.head.uri.hasSuffix(Consts.postInitErrorURL) {
            guard let json = requestBody, let error = ErrorResponse.fromJson(json) else {
                return self.writeResponse(context: context, status: .badRequest)
            }
            switch self.behavior.processInitError(error: error) {
            case .success:
                responseStatus = .accepted
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if request.head.uri.hasSuffix(Consts.getNextInvocationURLSuffix) {
            switch self.behavior.getInvocation() {
            case .success(let (requestId, result)):
                if requestId == "timeout" {
                    usleep((UInt32(result) ?? 0) * 1000)
                } else if requestId == "disconnect" {
                    return context.close(promise: nil)
                }
                responseStatus = .ok
                responseBody = result
                let deadline = Date(timeIntervalSinceNow: 60).millisSinceEpoch
                responseHeaders = [
                    (AmazonHeaders.requestID, requestId),
                    (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime"),
                    (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
                    (AmazonHeaders.deadline, String(deadline)),
                ]
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if request.head.uri.hasSuffix(Consts.postResponseURLSuffix) {
            guard let requestId = request.head.uri.split(separator: "/").dropFirst(3).first else {
                return self.writeResponse(context: context, status: .badRequest)
            }
            switch self.behavior.processResponse(requestId: String(requestId), response: requestBody) {
            case .success:
                responseStatus = .accepted
            case .failure(let error):
                responseStatus = .init(statusCode: error.rawValue)
            }
        } else if request.head.uri.hasSuffix(Consts.postErrorURLSuffix) {
            guard let requestId = request.head.uri.split(separator: "/").dropFirst(3).first,
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

    func writeResponse(
        context: ChannelHandlerContext,
        status: HTTPResponseStatus,
        headers: [(String, String)]? = nil,
        body: String? = nil
    ) {
        var headers = HTTPHeaders(headers ?? [])
        headers.add(name: "Content-Length", value: "\(body?.utf8.count ?? 0)")
        if !self.keepAlive {
            headers.add(name: "Connection", value: "close")
        }
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

        let loopBoundContext = NIOLoopBound(context, eventLoop: context.eventLoop)

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
            if case .failure(let error) = result {
                self.logger.error("\(self) write error \(error)")
            }
            if !self.keepAlive {
                let context = loopBoundContext.value
                context.close().whenFailure { error in
                    self.logger.error("\(self) close error \(error)")
                }
            }
        }
    }
}

protocol LambdaServerBehavior {
    func getInvocation() -> GetInvocationResult
    func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError>
    func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError>
    func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError>
}

typealias GetInvocationResult = Result<(String, String), GetWorkError>

enum GetWorkError: Int, Error {
    case badRequest = 400
    case tooManyRequests = 429
    case internalServerError = 500
}

enum ProcessResponseError: Int, Error {
    case badRequest = 400
    case payloadTooLarge = 413
    case tooManyRequests = 429
    case internalServerError = 500
}

enum ProcessErrorError: Int, Error {
    case invalidErrorShape = 299
    case badRequest = 400
    case internalServerError = 500
}

enum ServerError: Error {
    case notReady
    case cantBind
}

extension ErrorResponse {
    fileprivate static func fromJson(_ s: String) -> ErrorResponse? {
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
