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
/// Note that Lambda Runtime API dictate that only one requests runs at a time.
/// This means we can avoid locks and other concurrency concern we would otherwise need to build into the client
internal final class HTTPClient {
    private let eventLoop: EventLoop
    private let configuration: Lambda.Configuration.RuntimeEngine
    private let targetHost: String

    private var state = State.disconnected
    private let executing = NIOAtomic.makeAtomic(value: false)

    init(eventLoop: EventLoop, configuration: Lambda.Configuration.RuntimeEngine) {
        self.eventLoop = eventLoop
        self.configuration = configuration
        self.targetHost = "\(self.configuration.ip):\(self.configuration.port)"
    }

    func get(url: String, timeout: TimeAmount? = nil) -> EventLoopFuture<Response> {
        self.execute(Request(targetHost: self.targetHost,
                             url: url,
                             method: .GET,
                             timeout: timeout ?? self.configuration.requestTimeout))
    }

    func post(url: String, body: ByteBuffer?, timeout: TimeAmount? = nil) -> EventLoopFuture<Response> {
        self.execute(Request(targetHost: self.targetHost,
                             url: url,
                             method: .POST,
                             body: body,
                             timeout: timeout ?? self.configuration.requestTimeout))
    }

    // TODO: cap reconnect attempt
    private func execute(_ request: Request, validate: Bool = true) -> EventLoopFuture<Response> {
        precondition(!validate || self.executing.compareAndExchange(expected: false, desired: true), "expecting single request at a time")

        switch self.state {
        case .disconnected:
            return self.connect().flatMap { channel -> EventLoopFuture<Response> in
                self.state = .connected(channel)
                return self.execute(request, validate: false)
            }
        case .connected(let channel):
            guard channel.isActive else {
                self.state = .disconnected
                return self.execute(request, validate: false)
            }

            let promise = channel.eventLoop.makePromise(of: Response.self)
            promise.futureResult.whenComplete { _ in
                precondition(self.executing.compareAndExchange(expected: true, desired: false), "invalid execution state")
            }
            let wrapper = HTTPRequestWrapper(request: request, promise: promise)
            channel.writeAndFlush(wrapper).cascadeFailure(to: promise)
            return promise.futureResult
        }
    }

    private func connect() -> EventLoopFuture<Channel> {
        let bootstrap = ClientBootstrap(group: self.eventLoop)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandlers([HTTPHandler(keepAlive: self.configuration.keepAlive),
                                                  UnaryHandler(keepAlive: self.configuration.keepAlive)])
                }
            }

        do {
            // connect directly via socket address to avoid happy eyeballs (perf)
            let address = try SocketAddress(ipAddress: self.configuration.ip, port: self.configuration.port)
            return bootstrap.connect(to: address)
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }

    internal struct Request: Equatable {
        let url: String
        let method: HTTPMethod
        let targetHost: String
        let headers: HTTPHeaders
        let body: ByteBuffer?
        let timeout: TimeAmount?

        init(targetHost: String, url: String, method: HTTPMethod = .GET, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil, timeout: TimeAmount?) {
            self.targetHost = targetHost
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
            self.timeout = timeout
        }
    }

    internal struct Response: Equatable {
        public var version: HTTPVersion
        public var status: HTTPResponseStatus
        public var headers: HTTPHeaders
        public var body: ByteBuffer?
    }

    internal enum Errors: Error {
        case connectionResetByPeer
        case timeout
    }

    private enum State {
        case disconnected
        case connected(Channel)
    }
}

private final class HTTPHandler: ChannelDuplexHandler {
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

        var head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: request.method, uri: request.url, headers: request.headers)
        head.headers.add(name: "host", value: request.targetHost)
        switch request.method {
        case .POST, .PUT:
            head.headers.add(name: "content-length", value: String(request.body?.readableBytes ?? 0))
        default:
            break
        }

        // We don't add a "Connection" header here if we want to keep the connection open,
        // HTTP/1.1 defines specifies the following in RFC 2616, Section 8.1.2.1:
        //
        // An HTTP/1.1 server MAY assume that a HTTP/1.1 client intends to
        // maintain a persistent connection unless a Connection header including
        // the connection-token "close" was sent in the request. If the server
        // chooses to close the connection immediately after sending the
        // response, it SHOULD send a Connection header including the
        // connection-token close.
        //
        // See also UnaryHandler.channelRead below.
        if !self.keepAlive {
            head.headers.add(name: "connection", value: "close")
        }

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
                context.fireChannelRead(wrapInboundOut(HTTPClient.Response(version: head.version, status: head.status, headers: head.headers, body: nil)))
                self.readState = .idle
            case .body(let head, let body):
                context.fireChannelRead(wrapInboundOut(HTTPClient.Response(version: head.version, status: head.status, headers: head.headers, body: body)))
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

// no need in locks since we validate only one request can run at a time
private final class UnaryHandler: ChannelDuplexHandler {
    typealias OutboundIn = HTTPRequestWrapper
    typealias InboundIn = HTTPClient.Response
    typealias OutboundOut = HTTPClient.Request

    private let keepAlive: Bool

    private var pending: (promise: EventLoopPromise<HTTPClient.Response>, timeout: Scheduled<Void>?)?
    private var lastError: Error?

    init(keepAlive: Bool) {
        self.keepAlive = keepAlive
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard self.pending == nil else {
            preconditionFailure("invalid state, outstanding request")
        }
        let wrapper = unwrapOutboundIn(data)
        let timeoutTask = wrapper.request.timeout.map {
            context.eventLoop.scheduleTask(in: $0) {
                if self.pending != nil {
                    context.pipeline.fireErrorCaught(HTTPClient.Errors.timeout)
                }
            }
        }
        self.pending = (promise: wrapper.promise, timeout: timeoutTask)
        context.writeAndFlush(wrapOutboundOut(wrapper.request), promise: promise)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        guard let pending = self.pending else {
            preconditionFailure("invalid state, no pending request")
        }

        // As defined in RFC 2616 Section 8.1.2:
        // [...] unless otherwise indicated, the client SHOULD assume
        // that the server will maintain a persistent connection, even
        // after error responses from the server.
        let serverCloseConnection = response.headers.first(name: "connection")?.lowercased() == "close"

        if !self.keepAlive || serverCloseConnection || response.version != .init(major: 1, minor: 1) {
            pending.promise.futureResult.whenComplete { _ in
                _ = context.channel.close()
            }
        }
        self.completeWith(.success(response))
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // pending responses will fail with lastError in channelInactive since we are calling context.close
        self.lastError = error
        context.channel.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // fail any pending responses with last error or assume peer disconnected
        if self.pending != nil {
            let error = self.lastError ?? HTTPClient.Errors.connectionResetByPeer
            self.completeWith(.failure(error))
        }
        context.fireChannelInactive()
    }

    private func completeWith(_ result: Result<HTTPClient.Response, Error>) {
        guard let pending = self.pending else {
            preconditionFailure("invalid state, no pending request")
        }
        self.pending = nil
        self.lastError = nil
        pending.timeout?.cancel()
        pending.promise.completeWith(result)
    }
}

private struct HTTPRequestWrapper {
    let request: HTTPClient.Request
    let promise: EventLoopPromise<HTTPClient.Response>
}
