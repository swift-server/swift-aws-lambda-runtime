//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if DEBUG
@testable import AWSLambdaRuntimeCore
import Dispatch
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

// This functionality is designed for local testing hence beind a #if DEBUG flag.
// For example:
//
// try Lambda.withLocalServer {
//     Lambda.run { (context: Lambda.Context, payload: String, callback: @escaping (Result<String, Error>) -> Void) in
//         callback(.success("Hello, \(payload)!"))
//     }
// }
extension Lambda {
    /// Execute code in the context of a mock Lambda server.
    ///
    /// - parameters:
    ///     - invocationEndpoint: The endpoint  to post payloads to.
    ///     - body: Code to run within the context of the mock server. Typically this would be a Lambda.run function call.
    ///
    /// - note: This API is designed stricly for local testing and is behind a DEBUG flag
    public static func withLocalServer(proxyType: LocalLambdaInvocationProxy.Type = InvokeProxy.self, _ body: @escaping () -> Void) throws {
        let server = LocalLambda.Server(proxyType: proxyType)
        try server.start().wait()
        defer { try! server.stop() } // FIXME:
        body()
    }
}

public struct HTTPRequest {
    let method: HTTPMethod
    let uri: String
    let headers: [(String, String)]
    let body: ByteBuffer?

    internal init(head: HTTPRequestHead, body: ByteBuffer?) {
        self.method = head.method
        self.headers = head.headers.map { $0 }
        self.uri = head.uri
        self.body = body
    }
}

public struct HTTPResponse {
    var status: HTTPResponseStatus = .ok
    var headers: [(String, String)]?
    var body: ByteBuffer?
}

public struct InvocationHTTPError: Error {
    let response: HTTPResponse

    init(_ response: HTTPResponse) {
        self.response = response
    }
}

public protocol LocalLambdaInvocationProxy {
    init(eventLoop: EventLoop)

    /// throws HTTPError
    func invocation(from request: HTTPRequest) -> EventLoopFuture<ByteBuffer>
    func processResult(_ result: ByteBuffer?) -> EventLoopFuture<HTTPResponse>
    func processError(_ error: ByteBuffer?) -> EventLoopFuture<HTTPResponse>
}

// MARK: - Local Mock Server

private enum LocalLambda {
    struct Server {
        private let logger: Logger
        private let eventLoopGroup: EventLoopGroup
        private let eventLoop: EventLoop
        private let controlPlaneHost: String
        private let controlPlanePort: Int
        private let invokeAPIHost: String
        private let invokeAPIPort: Int
        private let proxy: LocalLambdaInvocationProxy

        public init(proxyType: LocalLambdaInvocationProxy.Type) {
            let configuration = Lambda.Configuration()
            var logger = Logger(label: "LocalLambdaServer")
            logger.logLevel = configuration.general.logLevel
            self.logger = logger
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.eventLoop = self.eventLoopGroup.next()
            self.controlPlaneHost = configuration.runtimeEngine.ip
            self.controlPlanePort = configuration.runtimeEngine.port
            self.invokeAPIHost = configuration.runtimeEngine.ip
            self.invokeAPIPort = configuration.runtimeEngine.port + 1
            self.proxy = proxyType.init(eventLoop: self.eventLoop)
        }

        func start() -> EventLoopFuture<Void> {
            let state = ServerState(eventLoop: self.eventLoop, logger: self.logger, proxy: self.proxy)

            let controlPlaneBootstrap = ServerBootstrap(group: eventLoopGroup)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                        channel.pipeline.addHandler(ControlPlaneHandler(logger: self.logger, serverState: state))
                    }
                }

            let invokeBootstrap = ServerBootstrap(group: eventLoopGroup)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                        channel.pipeline.addHandler(InvokeHandler(logger: self.logger, serverState: state))
                    }
                }

            let controlPlaneFuture = controlPlaneBootstrap.bind(host: self.controlPlaneHost, port: self.controlPlanePort).flatMap { channel -> EventLoopFuture<Void> in
                guard channel.localAddress != nil else {
                    return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
                }
                self.logger.info("Control plane api started and listening on \(self.controlPlaneHost):\(self.controlPlanePort)")
                return channel.eventLoop.makeSucceededFuture(())
            }

            let invokeAPIFuture = invokeBootstrap.bind(host: self.invokeAPIHost, port: self.invokeAPIPort).flatMap { channel -> EventLoopFuture<Void> in
                guard channel.localAddress != nil else {
                    return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
                }
                self.logger.info("Invocation proxy api started and listening on \(self.controlPlaneHost):\(self.controlPlanePort + 1)")
                return channel.eventLoop.makeSucceededFuture(())
            }

            return controlPlaneFuture.and(invokeAPIFuture).map { _ in Void() }
        }

        func stop() throws {
            try self.eventLoopGroup.syncShutdownGracefully()
        }
    }

    final class ServerState {
        private enum State {
            case waitingForInvocation(EventLoopPromise<Invocation>)
            case waitingForLambdaRequest
            case waitingForLambdaResponse(Invocation)
        }

        enum Error: Swift.Error {
            case invalidState
            case invalidRequestId
        }

        private var invocations = CircularBuffer<Invocation>()
        private var state = State.waitingForLambdaRequest
        private var logger: Logger

        let eventLoop: EventLoop
        let proxy: LocalLambdaInvocationProxy

        init(eventLoop: EventLoop, logger: Logger, proxy: LocalLambdaInvocationProxy) {
            self.eventLoop = eventLoop
            self.logger = logger
            self.proxy = proxy
        }

        // MARK: Invocation API

        func queueInvocationRequest(_ httpRequest: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
            self.proxy.invocation(from: httpRequest).flatMap { byteBuffer in
                let promise = self.eventLoop.makePromise(of: HTTPResponse.self)

                let uuid = "\(DispatchTime.now().uptimeNanoseconds)" // FIXME:
                let invocation = Invocation(requestID: uuid, request: byteBuffer, responsePromise: promise)

                switch self.state {
                case .waitingForInvocation(let promise):
                    self.state = .waitingForLambdaResponse(invocation)
                    promise.succeed(invocation)
                default:
                    self.invocations.append(invocation)
                }

                return promise.futureResult
            }
        }

        // MARK: Lambda Control Plane API

        func getNextInvocation() -> EventLoopFuture<Invocation> {
            guard case .waitingForLambdaRequest = self.state else {
                self.logger.error("invalid invocation state \(self.state)")
                return self.eventLoop.makeFailedFuture(Error.invalidState)
            }

            switch self.invocations.popFirst() {
            case .some(let invocation):
                // if there is a task pending, we can immediatly respond with it.
                self.state = .waitingForLambdaResponse(invocation)
                return self.eventLoop.makeSucceededFuture(invocation)
            case .none:
                // if there is nothing in the queue,
                // create a promise that we can fullfill when we get a new task
                let promise = self.eventLoop.makePromise(of: Invocation.self)
                self.state = .waitingForInvocation(promise)
                return promise.futureResult
            }
        }

        func processInvocationResult(for invocationId: String, body: ByteBuffer?) throws {
            let invocation = try self.pendingInvocation(for: invocationId)
            self.state = .waitingForLambdaRequest

            self.proxy.processResult(body).whenComplete { result in
                switch result {
                case .success(let response):
                    invocation.responsePromise.succeed(response)
                case .failure(let error):
                    invocation.responsePromise.fail(error)
                }
            }
        }

        func processInvocationError(for invocationId: String, body: ByteBuffer?) throws {
            let invocation = try self.pendingInvocation(for: invocationId)
            self.state = .waitingForLambdaRequest

            self.proxy.processError(body).whenComplete { result in
                switch result {
                case .success(let response):
                    invocation.responsePromise.succeed(response)
                case .failure(let error):
                    invocation.responsePromise.fail(error)
                }
            }
        }

        private func pendingInvocation(for requestID: String) throws -> Invocation {
            guard case .waitingForLambdaResponse(let invocation) = self.state else {
                // a response was send, but we did not expect to receive one
                self.logger.error("invalid invocation state \(self.state)")
                throw Error.invalidState
            }
            guard requestID == invocation.requestID else {
                // the request's requestId is not matching the one we are expecting
                self.logger.error("invalid invocation state request ID \(requestID) does not match expected \(invocation.requestID)")
                throw Error.invalidRequestId
            }

            return invocation
        }
    }

    final class ControlPlaneHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

        private let serverState: ServerState
        private let logger: Logger

        init(logger: Logger, serverState: ServerState) {
            self.logger = logger
            self.serverState = serverState
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
            switch (request.head.method, request.head.uri) {
            // /next endpoint is called by the lambda polling for work
            case (.GET, let url) where url.hasSuffix(Consts.getNextInvocationURLSuffix):
                // check if our server is in the correct state
                self.serverState.getNextInvocation().whenComplete { result in
                    switch result {
                    case .success(let invocation):
                        self.writeResponse(context: context, response: invocation.makeResponse())
                    case .failure(let error):
                        self.logger.error("invocation error: \(error)")
                        self.writeResponse(context: context, response: .init(status: .internalServerError))
                    }
                }

            // :requestID/response endpoint is called by the lambda posting the response
            case (.POST, let url) where url.hasSuffix(Consts.postResponseURLSuffix):
                let parts = request.head.uri.split(separator: "/")
                guard let requestID = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                    // the request is malformed, since we were expecting a requestId in the path
                    return self.writeResponse(context: context, response: .init(status: .badRequest))
                }

                do {
                    // a sync call here looks... interesting.
                    try self.serverState.processInvocationResult(for: requestID, body: request.body)
                    self.writeResponse(context: context, response: .init(status: .accepted))
                } catch {
                    self.writeResponse(context: context, response: .init(status: .badRequest))
                }

            // :requestID/error endpoint is called by the lambda posting an error
            case (.POST, let url) where url.hasSuffix(Consts.postErrorURLSuffix):
                let parts = request.head.uri.split(separator: "/")
                guard let requestID = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                    // the request is malformed, since we were expecting a requestId in the path
                    return self.writeResponse(context: context, response: .init(status: .badRequest))
                }

                do {
                    // a sync call here looks... interesting.
                    try self.serverState.processInvocationError(for: requestID, body: request.body)
                    self.writeResponse(context: context, response: .init(status: .accepted))
                } catch {
                    self.writeResponse(context: context, response: .init(status: .badRequest))
                }

            // unknown call
            default:
                self.writeResponse(context: context, response: .init(status: .notFound))
            }
        }

        func writeResponse(context: ChannelHandlerContext, response: HTTPResponse) {
            var headers = HTTPHeaders(response.headers ?? [])
            headers.add(name: "content-length", value: "\(response.body?.readableBytes ?? 0)")
            let head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: response.status, headers: headers)

            context.write(wrapOutboundOut(.head(head))).whenFailure { error in
                self.logger.error("\(self) write error \(error)")
            }

            if let buffer = response.body {
                context.write(wrapOutboundOut(.body(.byteBuffer(buffer)))).whenFailure { error in
                    self.logger.error("\(self) write error \(error)")
                }
            }

            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
                if case .failure(let error) = result {
                    self.logger.error("\(self) write error \(error)")
                }
            }
        }

        struct Invocation {
            let requestID: String
            let request: ByteBuffer
            let responsePromise: EventLoopPromise<HTTPResponse>

            func makeResponse() -> HTTPResponse {
                var response = HTTPResponse()
                response.body = self.request
                // required headers
                response.headers = [
                    (AmazonHeaders.requestID, self.requestID),
                    (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"),
                    (AmazonHeaders.traceID, "Root=\(Int16.random(in: Int16.min ... Int16.max));Parent=\(Int16.random(in: Int16.min ... Int16.max));Sampled=1"),
                    (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
                ]
                return response
            }
        }
    }

    final class InvokeHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

        private let serverState: ServerState
        private let logger: Logger

        init(logger: Logger, serverState: ServerState) {
            self.logger = logger
            self.serverState = serverState
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
            self.serverState.queueInvocationRequest(HTTPRequest(head: request.head, body: request.body)).whenComplete { result in
                switch result {
                case .success(let response):
                    self.writeResponse(context: context, response: response)
                case .failure(let error as InvocationHTTPError):
                    self.writeResponse(context: context, response: error.response)
                case .failure:
                    self.writeResponse(context: context, response: .init(status: .internalServerError))
                }
            }
        }

        func writeResponse(context: ChannelHandlerContext, response: HTTPResponse) {
            var headers = HTTPHeaders(response.headers ?? [])
            headers.add(name: "content-length", value: "\(response.body?.readableBytes ?? 0)")
            let head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: response.status, headers: headers)

            context.write(wrapOutboundOut(.head(head))).whenFailure { error in
                self.logger.error("\(self) write error \(error)")
            }

            if let buffer = response.body {
                context.write(wrapOutboundOut(.body(.byteBuffer(buffer)))).whenFailure { error in
                    self.logger.error("\(self) write error \(error)")
                }
            }

            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
                if case .failure(let error) = result {
                    self.logger.error("\(self) write error \(error)")
                }
            }
        }
    }

    struct Invocation {
        let requestID: String
        let request: ByteBuffer
        let responsePromise: EventLoopPromise<HTTPResponse>

        func makeResponse() -> HTTPResponse {
            var response = HTTPResponse()
            response.body = self.request
            // required headers
            response.headers = [
                (AmazonHeaders.requestID, self.requestID),
                (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"),
                (AmazonHeaders.traceID, "Root=\(Int16.random(in: Int16.min ... Int16.max));Parent=\(Int16.random(in: Int16.min ... Int16.max));Sampled=1"),
                (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
            ]
            return response
        }
    }

    enum ServerError: Error {
        case notReady
        case cantBind
    }
}

public struct InvokeProxy: LocalLambdaInvocationProxy {
    let eventLoop: EventLoop

    public init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    public func invocation(from request: HTTPRequest) -> EventLoopFuture<ByteBuffer> {
        switch (request.method, request.uri) {
        case (.POST, "/invoke"):
            guard let body = request.body else {
                return self.eventLoop.makeFailedFuture(InvocationHTTPError(.init(status: .badRequest)))
            }
            return self.eventLoop.makeSucceededFuture(body)
        default:
            return self.eventLoop.makeFailedFuture(InvocationHTTPError(.init(status: .notFound)))
        }
    }

    public func processResult(_ result: ByteBuffer?) -> EventLoopFuture<HTTPResponse> {
        self.eventLoop.makeSucceededFuture(.init(status: .ok, body: result))
    }

    public func processError(_ error: ByteBuffer?) -> EventLoopFuture<HTTPResponse> {
        self.eventLoop.makeSucceededFuture(.init(status: .internalServerError, body: error))
    }
}

#endif
