//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIO
import NIOHTTP1

internal struct MockServer {
    private let group: EventLoopGroup
    private let host: String
    private let port: Int
    private let mode: Mode

    public init() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.host = env("HOST") ?? "127.0.0.1"
        self.port = env("PORT").flatMap(Int.init) ?? 7000
        self.mode = env("MODE").flatMap(Mode.init) ?? .string
    }

    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                    channel.pipeline.addHandler(HTTPHandler(mode: self.mode))
                }
            }
        try bootstrap.bind(host: self.host, port: self.port).flatMap { channel -> EventLoopFuture<Void> in
            guard let localAddress = channel.localAddress else {
                return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
            }
            print("\(self) started and listening on \(localAddress)")
            return channel.eventLoop.makeSucceededFuture(())
        }.wait()
    }
}

internal final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private let mode: Mode

    private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

    public init(mode: Mode) {
        self.mode = mode
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
        var responseStatus: HTTPResponseStatus
        var responseBody: String?
        var responseHeaders: [(String, String)]?

        if request.head.uri.hasSuffix("/next") {
            let requestId = UUID().uuidString
            responseStatus = .ok
            switch self.mode {
            case .string:
                responseBody = requestId
            case .json:
                responseBody = "{ \"body\": \"\(requestId)\" }"
            }
            let deadline = Int64(Date(timeIntervalSinceNow: 60).timeIntervalSince1970 * 1000)
            responseHeaders = [
                (AmazonHeaders.requestID, requestId),
                (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime"),
                (AmazonHeaders.traceID, "Root=1-5bef4de7-ad49b0e87f6ef6c87fc2e700;Parent=9a9197af755a6419;Sampled=1"),
                (AmazonHeaders.deadline, String(deadline)),
            ]
        } else if request.head.uri.hasSuffix("/response") {
            responseStatus = .accepted
        } else {
            responseStatus = .notFound
        }
        self.writeResponse(context: context, status: responseStatus, headers: responseHeaders, body: responseBody)
    }

    func writeResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, headers: [(String, String)]? = nil, body: String? = nil) {
        var headers = HTTPHeaders(headers ?? [])
        headers.add(name: "content-length", value: "\(body?.utf8.count ?? 0)")
        let head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: status, headers: headers)

        context.write(wrapOutboundOut(.head(head))).whenFailure { error in
            print("\(self) write error \(error)")
        }

        if let b = body {
            var buffer = context.channel.allocator.buffer(capacity: b.utf8.count)
            buffer.writeString(b)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer)))).whenFailure { error in
                print("\(self) write error \(error)")
            }
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
            if case .failure(let error) = result {
                print("\(self) write error \(error)")
            }
        }
    }
}

internal enum ServerError: Error {
    case notReady
    case cantBind
}

internal enum AmazonHeaders {
    static let requestID = "Lambda-Runtime-Aws-Request-Id"
    static let traceID = "Lambda-Runtime-Trace-Id"
    static let clientContext = "X-Amz-Client-Context"
    static let cognitoIdentity = "X-Amz-Cognito-Identity"
    static let deadline = "Lambda-Runtime-Deadline-Ms"
    static let invokedFunctionARN = "Lambda-Runtime-Invoked-Function-Arn"
}

internal enum Mode: String {
    case string
    case json
}

func env(_ name: String) -> String? {
    guard let value = getenv(name) else {
        return nil
    }
    return String(cString: value)
}

// main
let server = MockServer()
try! server.start()
dispatchMain()
