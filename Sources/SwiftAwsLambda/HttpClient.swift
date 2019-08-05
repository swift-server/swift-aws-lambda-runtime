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
import NIO
import NIOHTTP1

/// A barebone HTTP client to interact with AWS Runtime Engine which is an HTTP server.
internal class HTTPClient {
    let eventLoop: EventLoop

    init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    func get(url: String) -> EventLoopFuture<HTTPResponse> {
        guard let request = HTTPRequest(url: url, method: .GET) else {
            return self.eventLoop.makeFailedFuture(HTTPClientError.invalidRequest)
        }
        return self.execute(request)
    }

    func post(url: String, body: ByteBuffer? = nil) -> EventLoopFuture<HTTPResponse> {
        guard let request = HTTPRequest(url: url, method: .POST, body: body) else {
            return self.eventLoop.makeFailedFuture(HTTPClientError.invalidRequest)
        }
        return self.execute(request)
    }

    func execute(_ request: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let bootstrap = ClientBootstrap(group: eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandlers([HTTPPartsHandler(), UnaryHTTPHandler()])
                }
            }

        return bootstrap.connect(host: request.host, port: request.port).flatMap { channel in
            let promise = channel.eventLoop.makePromise(of: HTTPResponse.self)
            let requestWrapper = HTTPRequestWrapper(request: request, promise: promise)

            return channel.writeAndFlush(NIOAny(requestWrapper)).flatMap { _ in
                promise.futureResult
            }
        }
    }
}

internal struct HTTPRequest: Equatable {
    public var version: HTTPVersion
    public var method: HTTPMethod
    public var target: String
    public var host: String
    public var port: Int
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    public init?(url: String, version: HTTPVersion = HTTPVersion(major: 1, minor: 1), method: HTTPMethod = .GET, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil) {
        guard let url = URL(string: url) else {
            return nil
        }

        self.init(url: url, version: version, method: method, headers: headers, body: body)
    }

    public init?(url: URL, version: HTTPVersion, method: HTTPMethod = .GET, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil) {
        guard let host = url.host else {
            return nil
        }

        self.version = version
        self.method = method
        self.target = url.path + (url.query.map { "?" + $0 } ?? "")
        self.host = host
        self.port = url.port ?? 80
        self.headers = headers
        self.body = body
    }
}

internal struct HTTPResponse: Equatable {
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?
}

private struct HTTPRequestWrapper {
    let request: HTTPRequest
    let promise: EventLoopPromise<HTTPResponse>

    init(request: HTTPRequest, promise: EventLoopPromise<HTTPResponse>) {
        self.request = request
        self.promise = promise
    }
}

private struct HTTPResponseAccumulator {
    enum State {
        case idle
        case head(HTTPResponseHead)
        case body(HTTPResponseHead, ByteBuffer)
        case end
    }

    var state = State.idle

    mutating func handle(_ head: HTTPResponseHead) {
        switch self.state {
        case .idle:
            self.state = .head(head)
        case .head:
            preconditionFailure("head already set")
        case .body:
            preconditionFailure("no head received before body")
        case .end:
            preconditionFailure("request already processed")
        }
    }

    mutating func handle(_ part: ByteBuffer) {
        switch self.state {
        case .idle:
            preconditionFailure("no head received before body")
        case .head(let head):
            self.state = .body(head, part)
        case .body(let head, var body):
            var part = part
            body.writeBuffer(&part)
            self.state = .body(head, body)
        case .end:
            preconditionFailure("request already processed")
        }
    }
}

private class HTTPPartsHandler: ChannelInboundHandler, ChannelOutboundHandler {
    typealias OutboundIn = HTTPRequest
    typealias InboundOut = HTTPResponse
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart

    var accumulator = HTTPResponseAccumulator()

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let request = unwrapOutboundIn(data)

        var head = HTTPRequestHead(version: request.version, method: request.method, uri: request.target)
        var headers = request.headers

        if request.version.major == 1, request.version.minor == 1, !request.headers.contains(name: "Host") {
            headers.add(name: "Host", value: request.host)
        }

        if let body = request.body {
            headers.add(name: "Content-Length", value: String(body.readableBytes))
        }

        head.headers = headers

        let part = HTTPClientRequestPart.head(head)

        let headPromise = context.eventLoop.makePromise(of: Void.self)
        let bodyPromise = context.eventLoop.makePromise(of: Void.self)

        context.write(wrapOutboundOut(part), promise: headPromise)

        if let body = request.body {
            let part = HTTPClientRequestPart.body(.byteBuffer(body))

            context.write(wrapOutboundOut(part), promise: bodyPromise)
        } else {
            bodyPromise.succeed(())
        }

        if let promise = promise {
            headPromise.futureResult.flatMap { bodyPromise.futureResult }.cascade(to: promise)
        }

        context.flush()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)

        switch response {
        case .head(let head):
            self.accumulator.handle(head)
        case .body(let body):
            self.accumulator.handle(body)
        case .end:
            switch self.accumulator.state {
            case .idle:
                preconditionFailure("no head received before end")
            case .head(let head):
                context.fireChannelRead(wrapInboundOut(HTTPResponse(status: head.status, headers: head.headers, body: nil)))
                self.accumulator.state = .end
            case .body(let head, let body):
                context.fireChannelRead(wrapInboundOut(HTTPResponse(status: head.status, headers: head.headers, body: body)))
                self.accumulator.state = .end
            case .end:
                preconditionFailure("request already processed")
            }
        }
    }
}

private class UnaryHTTPHandler: ChannelInboundHandler, ChannelOutboundHandler {
    typealias OutboundIn = HTTPRequestWrapper
    typealias InboundIn = HTTPResponse
    typealias OutboundOut = HTTPRequest

    var buffer = CircularBuffer<EventLoopPromise<HTTPResponse>>()

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let wrapper = unwrapOutboundIn(data)
        buffer.append(wrapper.promise)
        var request = wrapper.request
        request.headers.add(name: "Connection", value: "close")
        context.writeAndFlush(wrapOutboundOut(request), promise: promise)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        let promise = self.buffer.removeFirst()
        context.close().whenComplete { _ in
            promise.succeed(response)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close().whenComplete { _ in
            // In HTTP we should fail all promises as we close the Channel.
            self.failAllPromises(error: error)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        // Fail all promises
        self.failAllPromises(error: HTTPClientError.connectionClosed)
        context.fireChannelInactive()
    }

    private func failAllPromises(error: Error) {
        while let promise = buffer.first {
            promise.fail(error)
            self.buffer.removeFirst()
        }
    }
}

private enum HTTPClientError: Error {
    case invalidRequest
    case connectionClosed
}
