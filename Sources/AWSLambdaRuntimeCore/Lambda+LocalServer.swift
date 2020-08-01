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
extension Lambda {
    /// Execute code in the context of a mock Lambda server.
    ///
    /// - parameters:
    ///     - invocationEndpoint: The endpoint  to post events to.
    ///     - body: Code to run within the context of the mock server. Typically this would be a Lambda.run function call.
    ///
    /// - note: This API is designed stricly for local testing and is behind a DEBUG flag
    @discardableResult
    static func withLocalServer<Value>(invocationEndpoint: String? = nil, _ body: @escaping () -> Value) throws -> Value {
        let server = LocalLambda.Server(invocationEndpoint: invocationEndpoint)
        try server.start().wait()
        defer { try! server.stop() } // FIXME:
        return body()
    }
}

// MARK: - Local Mock Server

private enum LocalLambda {
    struct Server {
        private let logger: Logger
        private let group: EventLoopGroup
        private let host: String
        private let port: Int
        private let invocationEndpoint: String

        public init(invocationEndpoint: String?) {
            let configuration = Lambda.Configuration()
            var logger = Logger(label: "LocalLambdaServer")
            logger.logLevel = configuration.general.logLevel
            self.logger = logger
            self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.host = configuration.runtimeEngine.ip
            self.port = configuration.runtimeEngine.port
            self.invocationEndpoint = invocationEndpoint ?? "/invoke"
        }

        func start() -> EventLoopFuture<Void> {
            let bootstrap = ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                        channel.pipeline.addHandler(HTTPHandler(logger: self.logger, invocationEndpoint: self.invocationEndpoint))
                    }
                }
            return bootstrap.bind(host: self.host, port: self.port).flatMap { channel -> EventLoopFuture<Void> in
                guard channel.localAddress != nil else {
                    return channel.eventLoop.makeFailedFuture(ServerError.cantBind)
                }
                self.logger.info("LocalLambdaServer started and listening on \(self.host):\(self.port), receiving events on \(self.invocationEndpoint)")
                return channel.eventLoop.makeSucceededFuture(())
            }
        }

        func stop() throws {
            try self.group.syncShutdownGracefully()
        }
    }

    final class HTTPHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        private var pending = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()

        private static var invocations = CircularBuffer<Invocation>()
        private static var invocationState = InvocationState.waitingForLambdaRequest

        private let logger: Logger
        private let invocationEndpoint: String

        init(logger: Logger, invocationEndpoint: String) {
            self.logger = logger
            self.invocationEndpoint = invocationEndpoint
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
            // this endpoint is called by the client invoking the lambda
            case (.POST, let url) where url.hasSuffix(self.invocationEndpoint):
                guard let work = request.body else {
                    return self.writeResponse(context: context, response: .init(status: .badRequest))
                }
                let requestID = "\(DispatchTime.now().uptimeNanoseconds)" // FIXME:
                let promise = context.eventLoop.makePromise(of: Response.self)
                promise.futureResult.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        self.logger.error("invocation error: \(error)")
                        self.writeResponse(context: context, response: .init(status: .internalServerError))
                    case .success(let response):
                        self.writeResponse(context: context, response: response)
                    }
                }
                let invocation = Invocation(requestID: requestID, request: work, responsePromise: promise)
                switch Self.invocationState {
                case .waitingForInvocation(let promise):
                    promise.succeed(invocation)
                case .waitingForLambdaRequest, .waitingForLambdaResponse:
                    Self.invocations.append(invocation)
                }

            // /next endpoint is called by the lambda polling for work
            case (.GET, let url) where url.hasSuffix(Consts.getNextInvocationURLSuffix):
                // check if our server is in the correct state
                guard case .waitingForLambdaRequest = Self.invocationState else {
                    self.logger.error("invalid invocation state \(Self.invocationState)")
                    self.writeResponse(context: context, response: .init(status: .unprocessableEntity))
                    return
                }

                // pop the first task from the queue
                switch Self.invocations.popFirst() {
                case .none:
                    // if there is nothing in the queue,
                    // create a promise that we can fullfill when we get a new task
                    let promise = context.eventLoop.makePromise(of: Invocation.self)
                    promise.futureResult.whenComplete { result in
                        switch result {
                        case .failure(let error):
                            self.logger.error("invocation error: \(error)")
                            self.writeResponse(context: context, status: .internalServerError)
                        case .success(let invocation):
                            Self.invocationState = .waitingForLambdaResponse(invocation)
                            self.writeResponse(context: context, response: invocation.makeResponse())
                        }
                    }
                    Self.invocationState = .waitingForInvocation(promise)
                case .some(let invocation):
                    // if there is a task pending, we can immediatly respond with it.
                    Self.invocationState = .waitingForLambdaResponse(invocation)
                    self.writeResponse(context: context, response: invocation.makeResponse())
                }

            // :requestID/response endpoint is called by the lambda posting the response
            case (.POST, let url) where url.hasSuffix(Consts.postResponseURLSuffix):
                let parts = request.head.uri.split(separator: "/")
                guard let requestID = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                    // the request is malformed, since we were expecting a requestId in the path
                    return self.writeResponse(context: context, status: .badRequest)
                }
                guard case .waitingForLambdaResponse(let invocation) = Self.invocationState else {
                    // a response was send, but we did not expect to receive one
                    self.logger.error("invalid invocation state \(Self.invocationState)")
                    return self.writeResponse(context: context, status: .unprocessableEntity)
                }
                guard requestID == invocation.requestID else {
                    // the request's requestId is not matching the one we are expecting
                    self.logger.error("invalid invocation state request ID \(requestID) does not match expected \(invocation.requestID)")
                    return self.writeResponse(context: context, status: .badRequest)
                }

                invocation.responsePromise.succeed(.init(status: .ok, body: request.body))
                self.writeResponse(context: context, status: .accepted)
                Self.invocationState = .waitingForLambdaRequest

            // :requestID/error endpoint is called by the lambda posting an error response
            case (.POST, let url) where url.hasSuffix(Consts.postErrorURLSuffix):
                let parts = request.head.uri.split(separator: "/")
                guard let requestID = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                    // the request is malformed, since we were expecting a requestId in the path
                    return self.writeResponse(context: context, status: .badRequest)
                }
                guard case .waitingForLambdaResponse(let invocation) = Self.invocationState else {
                    // a response was send, but we did not expect to receive one
                    self.logger.error("invalid invocation state \(Self.invocationState)")
                    return self.writeResponse(context: context, status: .unprocessableEntity)
                }
                guard requestID == invocation.requestID else {
                    // the request's requestId is not matching the one we are expecting
                    self.logger.error("invalid invocation state request ID \(requestID) does not match expected \(invocation.requestID)")
                    return self.writeResponse(context: context, status: .badRequest)
                }

                invocation.responsePromise.succeed(.init(status: .internalServerError, body: request.body))
                self.writeResponse(context: context, status: .accepted)
                Self.invocationState = .waitingForLambdaRequest

            // unknown call
            default:
                self.writeResponse(context: context, status: .notFound)
            }
        }

        func writeResponse(context: ChannelHandlerContext, status: HTTPResponseStatus) {
            self.writeResponse(context: context, response: .init(status: status))
        }

        func writeResponse(context: ChannelHandlerContext, response: Response) {
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

        struct Response {
            var status: HTTPResponseStatus = .ok
            var headers: [(String, String)]?
            var body: ByteBuffer?
        }

        struct Invocation {
            let requestID: String
            let request: ByteBuffer
            let responsePromise: EventLoopPromise<Response>

            func makeResponse() -> Response {
                var response = Response()
                response.body = self.request
                // required headers
                response.headers = [
                    (AmazonHeaders.requestID, self.requestID),
                    (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"),
                    (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
                    (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
                ]
                return response
            }
        }

        enum InvocationState {
            case waitingForInvocation(EventLoopPromise<Invocation>)
            case waitingForLambdaRequest
            case waitingForLambdaResponse(Invocation)
        }
    }

    enum ServerError: Error {
        case notReady
        case cantBind
    }
}

#endif
