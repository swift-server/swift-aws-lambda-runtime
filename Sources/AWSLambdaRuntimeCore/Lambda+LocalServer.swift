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
import DequeModule
import Dispatch
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOPosix
import Synchronization

// This functionality is designed for local testing hence being a #if DEBUG flag.

// For example:
// try Lambda.withLocalServer {
//     try await LambdaRuntimeClient.withRuntimeClient(
//         configuration: .init(ip: "127.0.0.1", port: 7000),
//         eventLoop: self.eventLoop,
//         logger: self.logger
//     ) { runtimeClient in
//         try await Lambda.runLoop(
//             runtimeClient: runtimeClient,
//             handler: handler,
//             logger: self.logger
//         )
//     }
// }
extension Lambda {
    /// Execute code in the context of a mock Lambda server.
    ///
    /// - parameters:
    ///     - invocationEndpoint: The endpoint to post events to.
    ///     - body: Code to run within the context of the mock server. Typically this would be a Lambda.run function call.
    ///
    /// - note: This API is designed strictly for local testing and is behind a DEBUG flag
    static func withLocalServer(
        invocationEndpoint: String? = nil,
        _ body: sending @escaping () async throws -> Void
    ) async throws {
        var logger = Logger(label: "LocalServer")
        logger.logLevel = Lambda.env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info

        try await LambdaHTTPServer.withLocalServer(
            invocationEndpoint: invocationEndpoint,
            logger: logger
        ) {
            try await body()
        }
    }
}

// MARK: - Local HTTP Server

/// An HTTP server that behaves like the AWS Lambda service for local testing.
/// This server is used to simulate the AWS Lambda service for local testing but also to accept invocation requests from the lambda client.
///
/// It accepts three types of requests from the Lambda function (through the LambdaRuntimeClient):
/// 1. GET /next - the lambda function polls this endpoint to get the next invocation request
/// 2. POST /:requestID/response - the lambda function posts the response to the invocation request
/// 3. POST /:requestID/error - the lambda function posts an error response to the invocation request
///
/// It also accepts one type of request from the client invoking the lambda function:
/// 1. POST /invoke - the client posts the event to the lambda function
///
/// This server passes the data received from /invoke POST request to the lambda function (GET /next) and then forwards the response back to the client.
private struct LambdaHTTPServer {
    private let invocationEndpoint: String

    private let invocationPool = Pool<LocalServerInvocation>()
    private let responsePool = Pool<LocalServerResponse>()

    private init(
        invocationEndpoint: String?
    ) {
        self.invocationEndpoint = invocationEndpoint ?? "/invoke"
    }

    private enum TaskResult<Result: Sendable>: Sendable {
        case closureResult(Swift.Result<Result, any Error>)
        case serverReturned(Swift.Result<Void, any Error>)
    }

    struct UnsafeTransferBox<Value>: @unchecked Sendable {
        let value: Value

        init(value: sending Value) {
            self.value = value
        }
    }

    static func withLocalServer<Result: Sendable>(
        invocationEndpoint: String?,
        host: String = "127.0.0.1",
        port: Int = 7000,
        eventLoopGroup: MultiThreadedEventLoopGroup  = .singleton,
        logger: Logger,
        _ closure: sending @escaping () async throws -> Result
    ) async throws -> Result {
        let channel = try await ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 1)
            .bind(
                host: host,
                port: port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {

                    try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                        withErrorHandling: true
                    )

                    return try NIOAsyncChannel(
                        wrappingChannelSynchronously: channel,
                        configuration: NIOAsyncChannel.Configuration(
                            inboundType: HTTPServerRequestPart.self,
                            outboundType: HTTPServerResponsePart.self
                        )
                    )
                }
            }

        logger.info(
            "Server started and listening",
            metadata: [
                "host": "\(channel.channel.localAddress?.ipAddress?.debugDescription ?? "")",
                "port": "\(channel.channel.localAddress?.port ?? 0)",
            ]
        )

        let server = LambdaHTTPServer(invocationEndpoint: invocationEndpoint)

        // Sadly the Swift compiler does not understand that the passed in closure will only be
        // invoked once. Because of this we need an unsafe transfer box here. Buuuh!
        let closureBox = UnsafeTransferBox(value: closure)
        let result = await withTaskGroup(of: TaskResult<Result>.self, returning: Swift.Result<Result, any Error>.self) { group in
            group.addTask {
                let c = closureBox.value
                do {
                    let result = try await c()
                    return .closureResult(.success(result))
                } catch {
                    return .closureResult(.failure(error))
                }
            }

            group.addTask {
                do {
                    // We are handling each incoming connection in a separate child task. It is important
                    // to use a discarding task group here which automatically discards finished child tasks.
                    // A normal task group retains all child tasks and their outputs in memory until they are
                    // consumed by iterating the group or by exiting the group. Since, we are never consuming
                    // the results of the group we need the group to automatically discard them; otherwise, this
                    // would result in a memory leak over time.
                    try await withThrowingDiscardingTaskGroup { taskGroup in
                        try await channel.executeThenClose { inbound in
                            for try await connectionChannel in inbound {

                                taskGroup.addTask {
                                    logger.trace("Handling a new connection")
                                    await server.handleConnection(channel: connectionChannel, logger: logger)
                                    logger.trace("Done handling the connection")
                                }
                            }
                        }
                    }
                    return .serverReturned(.success(()))
                } catch {
                    return .serverReturned(.failure(error))
                }
            }

            let task1 = await group.next()!
            group.cancelAll()
            let task2 = await group.next()!

            switch task1 {
            case .closureResult(let result):
                return result

            case .serverReturned:
                switch task2 {
                case .closureResult(let result):
                    return result

                case .serverReturned:
                    fatalError()
                }
            }
        }

        logger.info("Server shutting down")
        return try result.get()
    }



    /// This method handles individual TCP connections
    private func handleConnection(
        channel: NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>,
        logger: Logger
    ) async {

        var requestHead: HTTPRequestHead!
        var requestBody: ByteBuffer?

        // Note that this method is non-throwing and we are catching any error.
        // We do this since we don't want to tear down the whole server when a single connection
        // encounters an error.
        do {
            try await channel.executeThenClose { inbound, outbound in
                for try await inboundData in inbound {
                    switch inboundData {
                    case .head(let head):
                        requestHead = head

                    case .body(let body):
                        requestBody = body

                    case .end:
                        precondition(requestHead != nil, "Received .end without .head")
                        // process the request
                        let response = try await self.processRequest(
                            head: requestHead,
                            body: requestBody,
                            logger: logger
                        )
                        // send the responses
                        try await self.sendResponse(
                            response: response,
                            outbound: outbound,
                            logger: logger
                        )

                        requestHead = nil
                        requestBody = nil
                    }
                }
            }
        } catch {
            logger.error("Hit error: \(error)")
        }
    }

    /// This function process the URI request sent by the client and by the Lambda function
    ///
    /// It enqueues the client invocation and iterate over the invocation queue when the Lambda function sends /next request
    /// It answers the /:requestID/response and /:requestID/error requests sent by the Lambda function but do not process the body
    ///
    /// - Parameters:
    ///   - head: the HTTP request head
    ///   - body: the HTTP request body
    /// - Throws:
    /// - Returns: the response to send back to the client or the Lambda function
    private func processRequest(head: HTTPRequestHead, body: ByteBuffer?, logger: Logger) async throws -> LocalServerResponse {

        if let body {
            logger.trace(
                "Processing request",
                metadata: ["URI": "\(head.method) \(head.uri)", "Body": "\(String(buffer: body))"]
            )
        } else {
            logger.trace("Processing request", metadata: ["URI": "\(head.method) \(head.uri)"])
        }

        switch (head.method, head.uri) {

        //
        // client invocations
        //
        // client POST /invoke
        case (.POST, let url) where url.hasSuffix(self.invocationEndpoint):
            guard let body else {
                return .init(status: .badRequest, headers: [], body: nil)
            }
            // we always accept the /invoke request and push them to the pool
            let requestId = "\(DispatchTime.now().uptimeNanoseconds)"
            var logger = logger
            logger[metadataKey: "requestID"] =  "\(requestId)"
            logger.trace("/invoke received invocation")
            await self.invocationPool.push(LocalServerInvocation(requestId: requestId, request: body))

            // wait for the lambda function to process the request
            for try await response in self.responsePool {
                logger.trace(
                    "Received response to return to client",
                    metadata: ["requestId": "\(response.requestId ?? "")"]
                )
                if response.requestId == requestId {
                    return response
                } else {
                    logger.error(
                        "Received response for a different request id",
                        metadata: ["response requestId": "\(response.requestId ?? "")", "requestId": "\(requestId)"]
                    )
                    // should we return an error here ? Or crash as this is probably a programming error?
                }
            }
            // What todo when there is no more responses to process?
            // This should not happen as the async iterator blocks until there is a response to process
            fatalError("No more responses to process - the async for loop should not return")

        // client uses incorrect HTTP method
        case (_, let url) where url.hasSuffix(self.invocationEndpoint):
            return .init(status: .methodNotAllowed)

        //
        // lambda invocations
        //

        // /next endpoint is called by the lambda polling for work
        // this call only returns when there is a task to give to the lambda function
        case (.GET, let url) where url.hasSuffix(Consts.getNextInvocationURLSuffix):

            // pop the tasks from the queue
            logger.trace("/next waiting for /invoke")
            for try await invocation in self.invocationPool {
                logger.trace("/next retrieved invocation", metadata: ["requestId": "\(invocation.requestId)"])
                // this call also stores the invocation requestId into the response
                return invocation.makeResponse(status: .accepted)
            }
            // What todo when there is no more tasks to process?
            // This should not happen as the async iterator blocks until there is a task to process
            fatalError("No more invocations to process - the async for loop should not return")

        // :requestID/response endpoint is called by the lambda posting the response
        case (.POST, let url) where url.hasSuffix(Consts.postResponseURLSuffix):
            let parts = head.uri.split(separator: "/")
            guard let requestId = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                // the request is malformed, since we were expecting a requestId in the path
                return .init(status: .badRequest)
            }
            // enqueue the lambda function response to be served as response to the client /invoke
            logger.trace("/:requestID/response received response", metadata: ["requestId": "\(requestId)"])
            await self.responsePool.push(
                LocalServerResponse(
                    id: requestId,
                    status: .ok,
                    headers: [("Content-Type", "application/json")],
                    body: body
                )
            )

            // tell the Lambda function we accepted the response
            return .init(id: requestId, status: .accepted)

        // :requestID/error endpoint is called by the lambda posting an error response
        // we accept all requestID and we do not handle the body, we just acknowledge the request
        case (.POST, let url) where url.hasSuffix(Consts.postErrorURLSuffix):
            let parts = head.uri.split(separator: "/")
            guard let _ = parts.count > 2 ? String(parts[parts.count - 2]) : nil else {
                // the request is malformed, since we were expecting a requestId in the path
                return .init(status: .badRequest)
            }
            return .init(status: .ok)

        // unknown call
        default:
            return .init(status: .notFound)
        }
    }

    private func sendResponse(
        response: LocalServerResponse,
        outbound: NIOAsyncChannelOutboundWriter<HTTPServerResponsePart>,
        logger: Logger
    ) async throws {
        var headers = HTTPHeaders(response.headers ?? [])
        headers.add(name: "Content-Length", value: "\(response.body?.readableBytes ?? 0)")

        logger.trace("Writing response", metadata: ["requestId": "\(response.requestId ?? "")"])
        try await outbound.write(
            HTTPServerResponsePart.head(
                HTTPResponseHead(
                    version: .init(major: 1, minor: 1),
                    status: response.status,
                    headers: headers
                )
            )
        )
        if let body = response.body {
            try await outbound.write(HTTPServerResponsePart.body(.byteBuffer(body)))
        }

        try await outbound.write(HTTPServerResponsePart.end(nil))
    }

    /// A shared data structure to store the current invocation or response requests and the continuation objects.
    /// This data structure is shared between instances of the HTTPHandler
    /// (one instance to serve requests from the Lambda function and one instance to serve requests from the client invoking the lambda function).
    private final class Pool<T>: AsyncSequence, AsyncIteratorProtocol, Sendable where T: Sendable {
        typealias Element = T

        struct State {
            enum State {
                case buffer(Deque<T>)
                case continuation(CheckedContinuation<T, any Error>?)
            }

            var state: State

            init() {
                self.state = .buffer([])
            }
        }

        private let lock = Mutex<State>(.init())

        /// enqueue an element, or give it back immediately to the iterator if it is waiting for an element
        public func push(_ invocation: T) async {
            // if the iterator is waiting for an element, give it to it
            // otherwise, enqueue the element
            let maybeContinuation = self.lock.withLock { state -> CheckedContinuation<T, any Error>? in
                switch state.state {
                case .continuation(let continuation):
                    state.state = .buffer([])
                    return continuation

                case .buffer(var buffer):
                    buffer.append(invocation)
                    state.state = .buffer(buffer)
                    return nil
                }
            }

            maybeContinuation?.resume(returning: invocation)
        }

        func next() async throws -> T? {
            // exit the async for loop if the task is cancelled
            guard !Task.isCancelled else {
                return nil
            }

            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                let nextAction = self.lock.withLock { state -> T? in
                    switch state.state {
                    case .buffer(var buffer):
                        if let first = buffer.popFirst() {
                            state.state = .buffer(buffer)
                            return first
                        } else {
                            state.state = .continuation(continuation)
                            return nil
                        }

                    case .continuation:
                        fatalError("Concurrent invocations to next(). This is illigal.")
                    }
                }

                guard let nextAction else { return }

                continuation.resume(returning: nextAction)
            }
        }

        func makeAsyncIterator() -> Pool {
            self
        }
    }

    private struct LocalServerResponse: Sendable {
        let requestId: String?
        let status: HTTPResponseStatus
        let headers: [(String, String)]?
        let body: ByteBuffer?
        init(id: String? = nil, status: HTTPResponseStatus, headers: [(String, String)]? = nil, body: ByteBuffer? = nil)
        {
            self.requestId = id
            self.status = status
            self.headers = headers
            self.body = body
        }
    }

    private struct LocalServerInvocation: Sendable {
        let requestId: String
        let request: ByteBuffer

        func makeResponse(status: HTTPResponseStatus) -> LocalServerResponse {

            // required headers
            let headers = [
                (AmazonHeaders.requestID, self.requestId),
                (
                    AmazonHeaders.invokedFunctionARN,
                    "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"
                ),
                (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
                (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
            ]

            return LocalServerResponse(id: self.requestId, status: status, headers: headers, body: self.request)
        }
    }
}
#endif
