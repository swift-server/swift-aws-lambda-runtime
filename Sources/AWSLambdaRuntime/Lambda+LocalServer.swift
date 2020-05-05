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

#if DEBUG
extension Lambda {
    /// Execute code in the context of a mock Lambda server.
    ///
    /// - parameters:
    ///     - invocationEndpoint: The endpoint  to post payloads to.
    ///     - body: Code to run within the context of the mock server. Typically this would be a Lambda.run function call.
    ///
    /// - note: This API is designed stricly for local testing and is behind a DEBUG flag
    public static func withLocalServer(invocationEndpoint: String? = nil, _ body: @escaping () -> Void) throws {
        let server = LocalLambda.Server(invocationEndpoint: invocationEndpoint)
        try server.start().wait()
        defer { try! server.stop() } // FIXME:
        body()
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
                self.logger.info("LocalLambdaServer started and listening on \(self.host):\(self.port), receiving payloads on \(self.invocationEndpoint)")
                return channel.eventLoop.makeSucceededFuture(())
            }
        }

        func stop() throws {
            try self.group.syncShutdownGracefully()
        }
    }

    final class HTTPHandler: ChannelInboundHandler {
        
        enum InvocationState {
            case waitingForNextRequest
            case idle(EventLoopPromise<Pending>)
            case processing(Pending)
        }
        
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        private var processing = CircularBuffer<(head: HTTPRequestHead, body: ByteBuffer?)>()
        
        private static let lock = Lock()
        private static var queue = [Pending]()
        private static var invocationState: InvocationState = .waitingForNextRequest

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
                self.processing.append((head: head, body: nil))
            case .body(var buffer):
                var request = self.processing.removeFirst()
                if request.body == nil {
                    request.body = buffer
                } else {
                    request.body!.writeBuffer(&buffer)
                }
                self.processing.prepend(request)
            case .end:
                let request = self.processing.removeFirst()
                self.processRequest(context: context, request: request)
            }
        }

        func processRequest(context: ChannelHandlerContext, request: (head: HTTPRequestHead, body: ByteBuffer?)) {
            if request.head.uri.hasSuffix(self.invocationEndpoint) {
                if let work = request.body {
                    let requestId = "\(DispatchTime.now().uptimeNanoseconds)" // FIXME:
                    let promise = context.eventLoop.makePromise(of: Response.self)
                    promise.futureResult.whenComplete { result in
                        switch result {
                        case .success(let response):
                            self.writeResponse(context: context, response: response)
                        case .failure:
                            self.writeResponse(context: context, response: .init(status: .internalServerError))
                        }
                    }
                    let pending = Pending(requestId: requestId, request: work, responsePromise: promise)
                    switch Self.lock.withLock({ Self.invocationState }) {
                    case .idle(let promise):
                        promise.succeed(pending)
                    case .processing(_), .waitingForNextRequest:
                        Self.queue.append(pending)
                    }
                }
            } else if request.head.uri.hasSuffix("/next") {
                // check if our server is in the correct state
                guard case .waitingForNextRequest = Self.lock.withLock({ Self.invocationState }) else {
                    #warning("better error code?!")
                    self.writeResponse(context: context, response: .init(status: .conflict))
                    return
                }
                
                // pop the first task from the queue
                switch (Self.lock.withLock { !Self.queue.isEmpty ? Self.queue.removeFirst() : nil }) {
                case .none:
                    // if there is nothing in the queue, create a promise that we can succeed,
                    // when we get a new task
                    let promise = context.eventLoop.makePromise(of: Pending.self)
                    promise.futureResult.whenComplete { (result) in
                        switch result {
                        case .failure(let error):
                            self.writeResponse(context: context, response: .init(status: .internalServerError))
                        case .success(let pending):
                            Self.lock.withLock {
                                Self.invocationState = .processing(pending)
                            }
                            self.writeResponse(context: context, response: pending.toResponse())
                        }
                    }
                    Self.lock.withLock {
                        Self.invocationState = .idle(promise)
                    }
                case .some(let pending):
                    Self.lock.withLock {
                        Self.invocationState = .processing(pending)
                    }
                    self.writeResponse(context: context, response: pending.toResponse())
                }

            } else if request.head.uri.hasSuffix("/response") {
                let parts = request.head.uri.split(separator: "/")
                guard let requestId = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                    // the request is malformed, since we were expecting a requestId in the path
                    return self.writeResponse(context: context, response: .init(status: .badRequest))
                }
                guard case .processing(let pending) = Self.lock.withLock({ Self.invocationState }) else {
                    // a response was send, but we did not expect to receive one
                    #warning("better error code?!")
                    return self.writeResponse(context: context, response: .init(status: .conflict))
                }
                guard requestId == pending.requestId else {
                    // the request's requestId is not matching the one we are expecting
                    return self.writeResponse(context: context, response: .init(status: .badRequest))
                }
                
                pending.responsePromise.succeed(.init(status: .ok, body: request.body))
                self.writeResponse(context: context, response: .init(status: .accepted))
                
                Self.lock.withLock {
                    Self.invocationState = .waitingForNextRequest
                }
            } else {
                self.writeResponse(context: context, response: .init(status: .notFound))
            }
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

        struct Pending {
            let requestId: String
            let request: ByteBuffer
            let responsePromise: EventLoopPromise<Response>
            
            func toResponse() -> Response {
                var response = Response()
                response.body = self.request
                // required headers
                response.headers = [
                    (AmazonHeaders.requestID, self.requestId),
                    (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"),
                    (AmazonHeaders.traceID, "Root=\(Int16.random(in: Int16.min ... Int16.max));Parent=\(Int16.random(in: Int16.min ... Int16.max));Sampled=1"),
                    (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
                ]
                return response
            }
        }
    }

    enum ServerError: Error {
        case notReady
        case cantBind
    }
}
#endif
