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

import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

/// A barebone HTTP client to interact with AWS Runtime Engine which is an HTTP server.
internal class HTTPClient {
    private let eventLoop: EventLoop
    private let configuration: Lambda.Configuration.RuntimeEngine

    private var state = State.disconnected
    private let lock = Lock()

    init(eventLoop: EventLoop, configuration: Lambda.Configuration.RuntimeEngine) {
        self.eventLoop = eventLoop
        self.configuration = configuration
    }

    func get(url: String, timeout: TimeAmount? = nil) -> EventLoopFuture<Response> {
        return self.execute(Request(url: self.configuration.baseURL.appendingPathComponent(url),
                                    method: .GET,
                                    timeout: timeout ?? self.configuration.requestTimeout))
    }

    func post(url: String, body: ByteBuffer, timeout: TimeAmount? = nil) -> EventLoopFuture<Response> {
        return self.execute(Request(url: self.configuration.baseURL.appendingPathComponent(url),
                                    method: .POST,
                                    body: body,
                                    timeout: timeout ?? self.configuration.requestTimeout))
    }

    private func execute(_ request: Request) -> EventLoopFuture<Response> {
        self.lock.lock()
        switch self.state {
        case .connected(let channel):
            guard channel.isActive else {
                // attempt to reconnect
                self.state = .disconnected
                self.lock.unlock()
                return self.execute(request)
            }
            self.lock.unlock()
            let promise = channel.eventLoop.makePromise(of: Response.self)
            let wrapper = HTTPRequestWrapper(request: request, promise: promise)
            return channel.writeAndFlush(wrapper).flatMap {
                promise.futureResult
            }
        case .disconnected:
            return self.connect().flatMap {
                self.lock.unlock()
                return self.execute(request)
            }
        default:
            preconditionFailure("invalid state \(self.state)")
        }
    }

    private func connect() -> EventLoopFuture<Void> {
        guard case .disconnected = self.state else {
            preconditionFailure("invalid state \(self.state)")
        }
        self.state = .connecting
        let bootstrap = ClientBootstrap(group: eventLoop)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandlers([HTTPHandler(keepAlive: self.configuration.keepAlive),
                                                  UnaryHandler(keepAlive: self.configuration.keepAlive)])
                }
            }
        return bootstrap.connect(host: self.configuration.baseURL.host, port: self.configuration.baseURL.port).flatMapThrowing { channel in
            self.state = .connected(channel)
        }
    }

    internal struct Request: Equatable {
        let url: Lambda.HTTPURL
        let method: HTTPMethod
        let target: String
        let headers: HTTPHeaders
        let body: ByteBuffer?
        let timeout: TimeAmount?

        init(url: Lambda.HTTPURL, method: HTTPMethod = .GET, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil, timeout: TimeAmount?) {
            self.url = url
            self.method = method
            self.target = url.path + (url.query.map { "?" + $0 } ?? "")
            self.headers = headers
            self.body = body
            self.timeout = timeout
        }
    }

    internal struct Response: Equatable {
        public var status: HTTPResponseStatus
        public var headers: HTTPHeaders
        public var body: ByteBuffer?
    }

    internal enum Errors: Error {
        case connectionResetByPeer
        case timeout
    }

    private enum State {
        case connecting
        case connected(Channel)
        case disconnected
    }
}

private class HTTPHandler: ChannelDuplexHandler {
    typealias OutboundIn = HTTPClient.Request
    typealias InboundOut = HTTPClient.Response
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart

    private let keepAlive: Bool
    private var readState: ReadState = .idle

    init(keepAlive: Bool) {
        self.keepAlive = keepAlive
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let request = unwrapOutboundIn(data)

        var head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: request.method, uri: request.target, headers: request.headers)
        if !head.headers.contains(name: "Host") {
            head.headers.add(name: "Host", value: request.url.host)
        }
        if let body = request.body {
            head.headers.add(name: "Content-Length", value: String(body.readableBytes))
        }
        head.headers.add(name: "Connection", value: self.keepAlive ? "keep-alive" : "close")

        context.write(self.wrapOutboundOut(HTTPClientRequestPart.head(head))).flatMap { _ -> EventLoopFuture<Void> in
            if let body = request.body {
                return context.writeAndFlush(self.wrapOutboundOut(HTTPClientRequestPart.body(.byteBuffer(body))))
            } else {
                context.flush()
                return context.eventLoop.makeSucceededFuture(())
            }
        }.cascade(to: promise)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)

        switch response {
        case .head(let head):
            guard case .idle = self.readState else {
                preconditionFailure("invalid read state \(self.readState)")
            }
            self.readState = .head(head)
        case .body(var bodyPart):
            switch self.readState {
            case .head(let head):
                self.readState = .body(head, bodyPart)
            case .body(let head, var body):
                body.writeBuffer(&bodyPart)
                self.readState = .body(head, body)
            default:
                preconditionFailure("invalid read state \(self.readState)")
            }
        case .end:
            switch self.readState {
            case .head(let head):
                context.fireChannelRead(wrapInboundOut(HTTPClient.Response(status: head.status, headers: head.headers, body: nil)))
                self.readState = .idle
            case .body(let head, let body):
                context.fireChannelRead(wrapInboundOut(HTTPClient.Response(status: head.status, headers: head.headers, body: body)))
                self.readState = .idle
            default:
                preconditionFailure("invalid read state \(self.readState)")
            }
        }
    }

    private enum ReadState {
        case idle
        case head(HTTPResponseHead)
        case body(HTTPResponseHead, ByteBuffer)
    }
}

private class UnaryHandler: ChannelInboundHandler, ChannelOutboundHandler {
    typealias OutboundIn = HTTPRequestWrapper
    typealias InboundIn = HTTPClient.Response
    typealias OutboundOut = HTTPClient.Request

    private let keepAlive: Bool

    private let lock = Lock()
    private var pendingResponses = CircularBuffer<(EventLoopPromise<HTTPClient.Response>, Scheduled<Void>?)>()
    private var lastError: Error?

    init(keepAlive: Bool) {
        self.keepAlive = keepAlive
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let wrapper = unwrapOutboundIn(data)
        let timeoutTask = wrapper.request.timeout.map {
            context.eventLoop.scheduleTask(in: $0) {
                if (self.lock.withLock { !self.pendingResponses.isEmpty }) {
                    self.errorCaught(context: context, error: HTTPClient.Errors.timeout)
                }
            }
        }
        self.lock.withLockVoid { pendingResponses.append((wrapper.promise, timeoutTask)) }
        context.writeAndFlush(wrapOutboundOut(wrapper.request), promise: promise)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        if let pending = (self.lock.withLock { self.pendingResponses.popFirst() }) {
            let serverKeepAlive = response.headers["connection"].first?.lowercased() == "keep-alive"
            let future = self.keepAlive && serverKeepAlive ? context.eventLoop.makeSucceededFuture(()) : context.channel.close()
            future.whenComplete { _ in
                pending.1?.cancel()
                pending.0.succeed(response)
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // pending responses will fail with lastError in channelInactive since we are calling context.close
        self.lock.withLockVoid { self.lastError = error }
        context.channel.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // fail any pending responses with last error or assume peer disconnected
        self.failPendingResponses(self.lock.withLock { self.lastError } ?? HTTPClient.Errors.connectionResetByPeer)
        context.fireChannelInactive()
    }

    private func failPendingResponses(_ error: Error) {
        while let pending = (self.lock.withLock { pendingResponses.popFirst() }) {
            pending.1?.cancel()
            pending.0.fail(error)
        }
    }
}

private struct HTTPRequestWrapper {
    let request: HTTPClient.Request
    let promise: EventLoopPromise<HTTPClient.Response>
}
