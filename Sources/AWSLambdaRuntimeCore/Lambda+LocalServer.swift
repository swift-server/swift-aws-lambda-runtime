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
import Dispatch
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

// This functionality is designed for local testing hence beind a #if DEBUG flag.
// For example:
//
// try Lambda.withLocalServer {
//     Lambda.run { (context: Lambda.Context, event: String, callback: @escaping (Result<String, Error>) -> Void) in
//         callback(.success("Hello, \(event)!"))
//     }
// }
internal extension Lambda {
    /// Execute code in the context of a mock Lambda server.
    ///
    /// - parameters:
    ///     - body: Code to run within the context of the mock server. Typically this would be a Lambda.run function call.
    ///
    /// - note: This API is designed stricly for local testing and is behind a DEBUG flag
    @discardableResult
    static func withLocalServer<Value>(_ body: @escaping () -> Value) throws -> Value {
        let server = LocalLambda.Server()
        try server.start().wait()
        defer { try! server.stop() } // FIXME:
        return body()
    }
}

// MARK: - Local Mock Server

public protocol LocalLambdaInvocationProxy {
    init(eventLoop: EventLoop)

    // TODO: in most (all?) cases we do not need async interface

    /// throws `LocalLambda.InvocationError` if request is invalid
    func invocation(from request: LocalLambda.HTTPRequest) -> EventLoopFuture<ByteBuffer>
    func processResult(_ result: ByteBuffer?) -> EventLoopFuture<LocalLambda.HTTPResponse>
    func processError(_ error: ByteBuffer?) -> EventLoopFuture<LocalLambda.HTTPResponse>
}

public enum LocalLambda {
    public struct HTTPRequest {
        public let method: HTTPMethod
        public let uri: String
        public let headers: [(String, String)]
        public let body: ByteBuffer?

        internal init(head: HTTPRequestHead, body: ByteBuffer?) {
            self.method = head.method
            self.headers = head.headers.map { $0 }
            self.uri = head.uri
            self.body = body
        }
    }

    public struct HTTPResponse {
        public var status: HTTPResponseStatus
        public var headers: [(String, String)]?
        public var body: ByteBuffer?
    }

    public enum InvocationError: Error {
        case badRequest
        case notFound
    }

    private static let lock = Lock()
    private static var proxyType: LocalLambdaInvocationProxy.Type = InvokeProxy.self

    public static func bootstrap(_ proxyType: LocalLambdaInvocationProxy.Type) {
        self.lock.withLockVoid {
            self.proxyType = proxyType
        }
    }

    fileprivate struct Server {
        enum ServerError: Error {
            case cantBind
        }

        private let logger: Logger
        private let eventLoopGroup: EventLoopGroup
        private let eventLoop: EventLoop
        private let controlPlaneHost: String
        private let controlPlanePort: Int
        private let invokeAPIHost: String
        private let invokeAPIPort: Int
        private let proxy: LocalLambdaInvocationProxy

        public init(configuration: Lambda.Configuration = Lambda.Configuration()) {
            var logger = Logger(label: "LocalLambdaServer")
            logger.logLevel = configuration.general.logLevel
            self.logger = logger
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.eventLoop = self.eventLoopGroup.next()
            self.controlPlaneHost = configuration.runtimeEngine.ip
            self.controlPlanePort = configuration.runtimeEngine.port
            self.invokeAPIHost = configuration.runtimeEngine.ip
            self.invokeAPIPort = configuration.runtimeEngine.port + 1
            let proxyType = LocalLambda.lock.withLock { LocalLambda.proxyType }
            self.proxy = proxyType.init(eventLoop: self.eventLoop)
        }

        func start() -> EventLoopFuture<Void> {
            let state = ServerState(eventLoop: self.eventLoop, logger: self.logger)

            let controlPlaneBootstrap = ServerBootstrap(group: eventLoopGroup)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                        channel.pipeline.addHandler(ControlPlaneHandler(logger: self.logger, serverState: state))
                    }
                }

            let invokeBootstrap = ServerBootstrap(group: eventLoopGroup)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                        channel.pipeline.addHandler(ProxyHandler(logger: self.logger, proxy: self.proxy) {
                            state.queueInvocation($0)
                        })
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

    // TODO: rename
    private final class ServerState {
        struct Invocation {
            let requestID: String
            let request: ByteBuffer
            let responsePromise: EventLoopPromise<InvocationResult>
        }

        enum InvocationResult {
            case success(ByteBuffer?)
            case failure(ByteBuffer?)
        }

        private enum State {
            case waitingForInvocation(EventLoopPromise<Invocation>)
            case waitingForLambdaRequest
            case waitingForLambdaResponse(Invocation)
        }

        enum StateError: Error {
            case invalidState
            case invalidRequestId
        }

        private var invocations = CircularBuffer<Invocation>()
        private var state = State.waitingForLambdaRequest
        private var logger: Logger

        private let eventLoop: EventLoop

        init(eventLoop: EventLoop, logger: Logger) {
            self.eventLoop = eventLoop
            self.logger = logger
        }

        // MARK: Invocation API

        /// Queues an invocation and promises to provide a result.
        func queueInvocation(_ byteBuffer: ByteBuffer) -> EventLoopFuture<InvocationResult> {
            let promise = self.eventLoop.makePromise(of: InvocationResult.self)

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

        // MARK: Lambda Control Plane API

        /// Returns `HTTPResponse` with the body containing the payload from the invocation.
        func getNextInvocation() -> EventLoopFuture<HTTPResponse> {
            guard case .waitingForLambdaRequest = self.state else {
                self.logger.error("invalid invocation state \(self.state)")
                return self.eventLoop.makeFailedFuture(StateError.invalidState)
            }

            func makeResponse(_ invocation: Invocation) -> HTTPResponse {
                var response = HTTPResponse(status: .ok)
                response.body = invocation.request
                // required headers
                response.headers = [
                    (AmazonHeaders.requestID, invocation.requestID),
                    (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"),
                    (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
                    (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
                ]
                return response
            }

            switch self.invocations.popFirst() {
            case .some(let invocation):
                // if there is a task pending, we can immediatly respond with it.
                self.state = .waitingForLambdaResponse(invocation)
                return self.eventLoop.makeSucceededFuture(invocation).map { makeResponse($0) }
            case .none:
                // if there is nothing in the queue,
                // create a promise that we can fullfill when we get a new task
                let promise = self.eventLoop.makePromise(of: Invocation.self)
                self.state = .waitingForInvocation(promise)
                return promise.futureResult.map { makeResponse($0) }
            }
        }

        private func pendingInvocation(for requestID: String) -> EventLoopFuture<Invocation> {
            guard case .waitingForLambdaResponse(let invocation) = self.state else {
                // a response was send, but we did not expect to receive one
                self.logger.error("invalid invocation state \(self.state)")
                return self.eventLoop.makeFailedFuture(StateError.invalidState)
            }
            guard requestID == invocation.requestID else {
                // the request's requestId is not matching the one we are expecting
                self.logger.error("invalid invocation state request ID \(requestID) does not match expected \(invocation.requestID)")
                return self.eventLoop.makeFailedFuture(StateError.invalidRequestId)
            }

            return self.eventLoop.makeSucceededFuture(invocation)
        }

        func processInvocationResult(for invocationId: String, body: ByteBuffer?) -> EventLoopFuture<Void> {
            self.pendingInvocation(for: invocationId)
                .always { result in
                    switch result {
                    case .success(let invocation):
                        invocation.responsePromise.succeed(.success(body))
                    case .failure(let error):
                        self.logger.error("Unknown invocationId \(invocationId): \(error)")
                    }
                    self.state = .waitingForLambdaRequest
                }
                .map { _ in }
        }

        func processInvocationError(for invocationId: String, body: ByteBuffer?) -> EventLoopFuture<Void> {
            self.pendingInvocation(for: invocationId)
                .always { result in
                    switch result {
                    case .success(let invocation):
                        invocation.responsePromise.succeed(.failure(body))
                    case .failure(let error):
                        self.logger.error("Unknown invocationId \(invocationId): \(error)")
                    }
                    self.state = .waitingForLambdaRequest
                }
                .map { _ in }
        }
    }

    /// Mocks an HTTP API for custom runtimes to receive invocation events from Lambda and send response data back, see
    /// [AWS Lambda runtime interface](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html).
    private final class ControlPlaneHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart

        // TODO: do we need a circular buffer? there is only (up to) one request at a time
        private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

        // TODO: should we not just create a logger instance(s) within the class?
        private let logger: Logger
        private let serverState: ServerState

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
                    case .success(let response):
                        self.writeResponse(context: context, response: response)
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

                self.serverState.processInvocationResult(for: requestID, body: request.body)
                    .whenComplete { result in
                        switch result {
                        case .success:
                            self.writeResponse(context: context, response: .init(status: .accepted))
                        case .failure:
                            self.writeResponse(context: context, response: .init(status: .badRequest))
                        }
                    }

            // :requestID/error endpoint is called by the lambda posting an error
            case (.POST, let url) where url.hasSuffix(Consts.postErrorURLSuffix):
                let parts = request.head.uri.split(separator: "/")
                guard let requestID = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                    // the request is malformed, since we were expecting a requestId in the path
                    return self.writeResponse(context: context, response: .init(status: .badRequest))
                }

                self.serverState.processInvocationError(for: requestID, body: request.body)
                    .whenComplete { result in
                        switch result {
                        case .success:
                            self.writeResponse(context: context, response: .init(status: .accepted))
                        case .failure:
                            self.writeResponse(context: context, response: .init(status: .badRequest))
                        }
                    }

            // unknown call
            default:
                self.writeResponse(context: context, response: .init(status: .notFound))
            }
        }

        func writeResponse(context: ChannelHandlerContext, response: HTTPResponse) {
            self.writeResponse(context: context, response: response) { error in
                self.logger.error("Failed to write response: \(error)")
            }
        }
    }

    /// Creates and queues lambda invocations.
    /// Maps incoming HTTP requests to events expected by `LambdaHandler` and its response back to a HTTP response for HTTP client.
    private final class ProxyHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        // TODO: do we need a circular buffer? there is only one request at a time, no?
        private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

        private let logger: Logger
        private let proxy: LocalLambdaInvocationProxy
        private let callback: (_ byteBuffer: ByteBuffer) -> EventLoopFuture<ServerState.InvocationResult>

        init(logger: Logger, proxy: LocalLambdaInvocationProxy,
             callback: @escaping (_ byteBuffer: ByteBuffer) -> EventLoopFuture<ServerState.InvocationResult>) {
            self.logger = logger
            self.proxy = proxy
            self.callback = callback
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
            let httpRequest = HTTPRequest(head: request.head, body: request.body)
            // map the request using the proxy
            let httpResponse: EventLoopFuture<LocalLambda.HTTPResponse> = self.proxy.invocation(from: httpRequest)
                // wait for response from the lambda handler
                .flatMap { self.callback($0) }
                // map the response using the proxy
                .flatMap { result in
                    switch result {
                    case .success(let body):
                        return self.proxy.processResult(body)
                    case .failure(let body):
                        return self.proxy.processError(body)
                    }
                }
            // write HTTP response to HTTP client
            httpResponse.whenComplete { result in
                let output: LocalLambda.HTTPResponse
                switch result {
                case .success(let response):
                    output = response
                case .failure(let error as LocalLambda.InvocationError):
                    output = .init(error: error)
                case .failure:
                    output = .init(status: .internalServerError)
                }
                self.writeResponse(context: context, response: output) { error in
                    self.logger.error("Failed to write response: \(error)")
                }
            }
        }
    }
}

// MARK: - LocalLambda.HTTPResponse helpers

private extension LocalLambda.HTTPResponse {
    init(error: LocalLambda.InvocationError) {
        switch error {
        case .badRequest:
            self.init(status: .badRequest)
        case .notFound:
            self.init(status: .notFound)
        }
    }
}

private extension ChannelInboundHandler where InboundIn == HTTPServerRequestPart, OutboundOut == HTTPServerResponsePart {
    func writeResponse(context: ChannelHandlerContext, response: LocalLambda.HTTPResponse, errorHandler: @escaping (Error) -> Void) {
        var headers = HTTPHeaders(response.headers ?? [])
        if headers.contains(name: "Content-Length") == false {
            headers.add(name: "Content-Length", value: "\(response.body?.readableBytes ?? 0)")
        }
        let head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: response.status, headers: headers)

        context.write(wrapOutboundOut(.head(head))).whenFailure(errorHandler)

        // TODO: does it make sense to keep writing if failed?

        if let buffer = response.body {
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer)))).whenFailure(errorHandler)
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { result in
            if case .failure(let error) = result {
                errorHandler(error)
            }
        }
    }
}

// MARK: - InvokeProxy

// TODO: not sure if it needs to be public, if so perhaps it should be within LocalLambda namespace
public struct InvokeProxy: LocalLambdaInvocationProxy {
    let eventLoop: EventLoop

    public init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    public func invocation(from request: LocalLambda.HTTPRequest) -> EventLoopFuture<ByteBuffer> {
        switch (request.method, request.uri) {
        case (.POST, "/invoke"):
            guard let body = request.body else {
                return self.eventLoop.makeFailedFuture(LocalLambda.InvocationError.badRequest)
            }
            return self.eventLoop.makeSucceededFuture(body)
        default:
            return self.eventLoop.makeFailedFuture(LocalLambda.InvocationError.notFound)
        }
    }

    public func processResult(_ result: ByteBuffer?) -> EventLoopFuture<LocalLambda.HTTPResponse> {
        self.eventLoop.makeSucceededFuture(.init(status: .ok, body: result))
    }

    public func processError(_ error: ByteBuffer?) -> EventLoopFuture<LocalLambda.HTTPResponse> {
        self.eventLoop.makeSucceededFuture(.init(status: .internalServerError, body: error))
    }
}

#endif
