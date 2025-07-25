//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if LocalServerSupport
import DequeModule
import Dispatch
import Logging
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
    @usableFromInline
    static func withLocalServer(
        invocationEndpoint: String? = nil,
        logger: Logger,
        _ body: sending @escaping () async throws -> Void
    ) async throws {
        _ = try await LambdaHTTPServer.withLocalServer(
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
/// 2. POST /:requestId/response - the lambda function posts the response to the invocation request
/// 3. POST /:requestId/error - the lambda function posts an error response to the invocation request
///
/// It also accepts one type of request from the client invoking the lambda function:
/// 1. POST /invoke - the client posts the event to the lambda function
///
/// This server passes the data received from /invoke POST request to the lambda function (GET /next) and then forwards the response back to the client.
internal struct LambdaHTTPServer {
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

    fileprivate struct UnsafeTransferBox<Value>: @unchecked Sendable {
        let value: Value

        init(value: sending Value) {
            self.value = value
        }
    }

    static func withLocalServer<Result: Sendable>(
        invocationEndpoint: String?,
        host: String = "127.0.0.1",
        port: Int = 7000,
        eventLoopGroup: MultiThreadedEventLoopGroup = .singleton,
        logger: Logger,
        _ closure: sending @escaping () async throws -> Result
    ) async throws -> Swift.Result<Result, any Error> {
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

        // it's ok to keep this at `info` level because it is only used for local testing and unit tests
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
        let result = await withTaskGroup(of: TaskResult<Result>.self, returning: Swift.Result<Result, any Error>.self) {
            group in
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
                    try await withTaskCancellationHandler {
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
                    } onCancel: {
                        channel.channel.close(promise: nil)
                    }
                    return .serverReturned(.success(()))
                } catch {
                    return .serverReturned(.failure(error))
                }
            }

            // Now that the local HTTP server and LambdaHandler tasks are started, wait for the
            // first of the two that will terminate.
            // When the first task terminates, cancel the group and collect the result of the
            // second task.

            // collect and return the result of the LambdaHandler
            let serverOrHandlerResult1 = await group.next()!
            group.cancelAll()

            switch serverOrHandlerResult1 {
            case .closureResult(let result):
                return result

            case .serverReturned(let result):

                if result.maybeError is CancellationError {
                    logger.trace("Server's task cancelled")
                } else {
                    logger.error(
                        "Server shutdown before closure completed",
                        metadata: [
                            "error": "\(result.maybeError != nil ? "\(result.maybeError!)" : "none")"
                        ]
                    )
                }

                switch await group.next()! {
                case .closureResult(let result):
                    return result

                case .serverReturned:
                    fatalError("Only one task is a server, and only one can return `serverReturned`")
                }
            }
        }

        logger.info("Server shutting down")
        if case .failure(let error) = result {
            logger.error("Error during server shutdown: \(error)")
        }        
        return result 
    }

    /// This method handles individual TCP connections
    private func handleConnection(
        channel: NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>,
        logger: Logger
    ) async {

        var requestHead: HTTPRequestHead!
        var requestBody: ByteBuffer?
        var requestId: String?

        // Note that this method is non-throwing and we are catching any error.
        // We do this since we don't want to tear down the whole server when a single connection
        // encounters an error.
        await withTaskCancellationHandler {
            do {
                try await channel.executeThenClose { inbound, outbound in
                    for try await inboundData in inbound {
                        switch inboundData {
                        case .head(let head):
                            requestHead = head
                            requestId = getRequestId(from: requestHead)

                            // for streaming requests, push a partial head response
                            if self.isStreamingResponse(requestHead) {
                                await self.responsePool.push(
                                    LocalServerResponse(
                                        id: requestId,
                                        status: .ok
                                    )
                                )
                            }

                        case .body(let body):
                            precondition(requestHead != nil, "Received .body without .head")

                            // if this is a request from a Streaming Lambda Handler,
                            // stream the response instead of buffering it
                            if self.isStreamingResponse(requestHead) {
                                await self.responsePool.push(
                                    LocalServerResponse(id: requestId, body: body)
                                )
                            } else {
                                requestBody.setOrWriteImmutableBuffer(body)
                            }

                        case .end:
                            precondition(requestHead != nil, "Received .end without .head")

                            if self.isStreamingResponse(requestHead) {
                                // for streaming response, send the final response
                                await self.responsePool.push(
                                    LocalServerResponse(id: requestId, final: true)
                                )
                            } else {
                                // process the buffered response for non streaming requests
                                try await self.processRequestAndSendResponse(
                                    head: requestHead,
                                    body: requestBody,
                                    outbound: outbound,
                                    logger: logger
                                )
                            }

                            // reset the request state for next request
                            requestHead = nil
                            requestBody = nil
                            requestId = nil
                        }
                    }
                }
            } catch let error as CancellationError {
                logger.trace("The task was cancelled", metadata: ["error": "\(error)"])
            } catch {
                logger.error("Hit error: \(error)")
            }

        } onCancel: {
            channel.channel.close(promise: nil)
        }
    }

    /// This function checks if the request is a streaming response request
    /// verb = POST, uri = :requestId/response, HTTP Header contains "Transfer-Encoding: chunked"
    private func isStreamingResponse(_ requestHead: HTTPRequestHead) -> Bool {
        requestHead.method == .POST && requestHead.uri.hasSuffix(Consts.postResponseURLSuffix)
            && requestHead.headers.contains(name: "Transfer-Encoding")
            && (requestHead.headers["Transfer-Encoding"].contains("chunked")
                || requestHead.headers["Transfer-Encoding"].contains("Chunked"))
    }

    /// This function parses and returns the requestId or nil if the request doesn't contain a requestId
    private func getRequestId(from head: HTTPRequestHead) -> String? {
        let parts = head.uri.split(separator: "/")
        return parts.count > 2 ? String(parts[parts.count - 2]) : nil
    }
    /// This function process the URI request sent by the client and by the Lambda function
    ///
    /// It enqueues the client invocation and iterate over the invocation queue when the Lambda function sends /next request
    /// It answers the /:requestId/response and /:requestId/error requests sent by the Lambda function but do not process the body
    ///
    /// - Parameters:
    ///   - head: the HTTP request head
    ///   - body: the HTTP request body
    /// - Throws:
    /// - Returns: the response to send back to the client or the Lambda function
    private func processRequestAndSendResponse(
        head: HTTPRequestHead,
        body: ByteBuffer?,
        outbound: NIOAsyncChannelOutboundWriter<HTTPServerResponsePart>,
        logger: Logger
    ) async throws {

        var logger = logger
        logger[metadataKey: "URI"] = "\(head.method) \(head.uri)"
        if let body {
            logger.trace(
                "Processing request",
                metadata: ["Body": "\(String(buffer: body))"]
            )
        } else {
            logger.trace("Processing request")
        }

        switch (head.method, head.uri) {

        //
        // client invocations
        //
        // client POST /invoke
        case (.POST, let url) where url.hasSuffix(self.invocationEndpoint):
            guard let body else {
                return try await sendResponse(
                    .init(status: .badRequest, final: true),
                    outbound: outbound,
                    logger: logger
                )
            }
            // we always accept the /invoke request and push them to the pool
            let requestId = "\(DispatchTime.now().uptimeNanoseconds)"
            logger[metadataKey: "requestId"] = "\(requestId)"
            logger.trace("/invoke received invocation, pushing it to the pool and wait for a lambda response")
            await self.invocationPool.push(LocalServerInvocation(requestId: requestId, request: body))

            // wait for the lambda function to process the request
            for try await response in self.responsePool {
                logger[metadataKey: "response requestId"] = "\(response.requestId ?? "nil")"
                logger.trace("Received response to return to client")
                if response.requestId == requestId {
                    logger.trace("/invoke requestId is valid, sending the response")
                    // send the response to the client
                    // if the response is final, we can send it and return
                    // if the response is not final, we can send it and wait for the next response
                    try await self.sendResponse(response, outbound: outbound, logger: logger)
                    if response.final == true {
                        logger.trace("/invoke returning")
                        return  // if the response is final, we can return and close the connection
                    }
                } else {
                    logger.error(
                        "Received response for a different request id",
                        metadata: ["response requestId": "\(response.requestId ?? "")"]
                    )
                    // should we return an error here ? Or crash as this is probably a programming error?
                }
            }
            // What todo when there is no more responses to process?
            // This should not happen as the async iterator blocks until there is a response to process
            fatalError("No more responses to process - the async for loop should not return")

        // client uses incorrect HTTP method
        case (_, let url) where url.hasSuffix(self.invocationEndpoint):
            return try await sendResponse(
                .init(status: .methodNotAllowed, final: true),
                outbound: outbound,
                logger: logger
            )

        //
        // lambda invocations
        //

        // /next endpoint is called by the lambda polling for work
        // this call only returns when there is a task to give to the lambda function
        case (.GET, let url) where url.hasSuffix(Consts.getNextInvocationURLSuffix):

            // pop the tasks from the queue
            logger.trace("/next waiting for /invoke")
            for try await invocation in self.invocationPool {
                logger[metadataKey: "requestId"] = "\(invocation.requestId)"
                logger.trace("/next retrieved invocation")
                // tell the lambda function we accepted the invocation
                return try await sendResponse(invocation.acceptedResponse(), outbound: outbound, logger: logger)
            }
            // What todo when there is no more tasks to process?
            // This should not happen as the async iterator blocks until there is a task to process
            fatalError("No more invocations to process - the async for loop should not return")

        // :requestId/response endpoint is called by the lambda posting the response
        case (.POST, let url) where url.hasSuffix(Consts.postResponseURLSuffix):
            guard let requestId = getRequestId(from: head) else {
                // the request is malformed, since we were expecting a requestId in the path
                return try await sendResponse(
                    .init(status: .badRequest, final: true),
                    outbound: outbound,
                    logger: logger
                )
            }
            // enqueue the lambda function response to be served as response to the client /invoke
            logger.trace("/:requestId/response received response", metadata: ["requestId": "\(requestId)"])
            await self.responsePool.push(
                LocalServerResponse(
                    id: requestId,
                    status: .ok,
                    // the local server has no mecanism to collect headers set by the lambda function
                    headers: HTTPHeaders(),
                    body: body,
                    final: true
                )
            )

            // tell the Lambda function we accepted the response
            return try await sendResponse(
                .init(id: requestId, status: .accepted, final: true),
                outbound: outbound,
                logger: logger
            )

        // :requestId/error endpoint is called by the lambda posting an error response
        // we accept all requestId and we do not handle the body, we just acknowledge the request
        case (.POST, let url) where url.hasSuffix(Consts.postErrorURLSuffix):
            guard let requestId = getRequestId(from: head) else {
                // the request is malformed, since we were expecting a requestId in the path
                return try await sendResponse(
                    .init(status: .badRequest, final: true),
                    outbound: outbound,
                    logger: logger
                )
            }
            // enqueue the lambda function response to be served as response to the client /invoke
            logger.trace("/:requestId/response received response", metadata: ["requestId": "\(requestId)"])
            await self.responsePool.push(
                LocalServerResponse(
                    id: requestId,
                    status: .internalServerError,
                    headers: HTTPHeaders([("Content-Type", "application/json")]),
                    body: body,
                    final: true
                )
            )

            return try await sendResponse(.init(status: .accepted, final: true), outbound: outbound, logger: logger)

        // unknown call
        default:
            return try await sendResponse(.init(status: .notFound, final: true), outbound: outbound, logger: logger)
        }
    }

    private func sendResponse(
        _ response: LocalServerResponse,
        outbound: NIOAsyncChannelOutboundWriter<HTTPServerResponsePart>,
        logger: Logger
    ) async throws {
        var logger = logger
        logger[metadataKey: "requestId"] = "\(response.requestId ?? "nil")"
        logger.trace("Writing response for \(response.status?.code ?? 0)")

        var headers = response.headers ?? HTTPHeaders()
        if let body = response.body {
            headers.add(name: "Content-Length", value: "\(body.readableBytes)")
        }

        if let status = response.status {
            logger.trace("Sending status and headers")
            try await outbound.write(
                HTTPServerResponsePart.head(
                    HTTPResponseHead(
                        version: .init(major: 1, minor: 1),
                        status: status,
                        headers: headers
                    )
                )
            )
        }

        if let body = response.body {
            logger.trace("Sending body")
            try await outbound.write(HTTPServerResponsePart.body(.byteBuffer(body)))
        }

        if response.final {
            logger.trace("Sending end")
            try await outbound.write(HTTPServerResponsePart.end(nil))
        }
    }

    /// A shared data structure to store the current invocation or response requests and the continuation objects.
    /// This data structure is shared between instances of the HTTPHandler
    /// (one instance to serve requests from the Lambda function and one instance to serve requests from the client invoking the lambda function).
    internal final class Pool<T>: AsyncSequence, AsyncIteratorProtocol, Sendable where T: Sendable {
        typealias Element = T

        enum State: ~Copyable {
            case buffer(Deque<T>)
            case continuation(CheckedContinuation<T, any Error>?)
        }

        private let lock = Mutex<State>(.buffer([]))

        /// enqueue an element, or give it back immediately to the iterator if it is waiting for an element
        public func push(_ invocation: T) async {
            // if the iterator is waiting for an element, give it to it
            // otherwise, enqueue the element
            let maybeContinuation = self.lock.withLock { state -> CheckedContinuation<T, any Error>? in
                switch consume state {
                case .continuation(let continuation):
                    state = .buffer([])
                    return continuation

                case .buffer(var buffer):
                    buffer.append(invocation)
                    state = .buffer(buffer)
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

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                    let nextAction = self.lock.withLock { state -> T? in
                        switch consume state {
                        case .buffer(var buffer):
                            if let first = buffer.popFirst() {
                                state = .buffer(buffer)
                                return first
                            } else {
                                state = .continuation(continuation)
                                return nil
                            }

                        case .continuation:
                            fatalError("Concurrent invocations to next(). This is illegal.")
                        }
                    }

                    guard let nextAction else { return }

                    continuation.resume(returning: nextAction)
                }
            } onCancel: {
                self.lock.withLock { state in
                    switch consume state {
                    case .buffer(let buffer):
                        state = .buffer(buffer)
                    case .continuation(let continuation):
                        continuation?.resume(throwing: CancellationError())
                        state = .buffer([])
                    }
                }
            }
        }

        func makeAsyncIterator() -> Pool {
            self
        }
    }

    private struct LocalServerResponse: Sendable {
        let requestId: String?
        let status: HTTPResponseStatus?
        let headers: HTTPHeaders?
        let body: ByteBuffer?
        let final: Bool
        init(
            id: String? = nil,
            status: HTTPResponseStatus? = nil,
            headers: HTTPHeaders? = nil,
            body: ByteBuffer? = nil,
            final: Bool = false
        ) {
            self.requestId = id
            self.status = status
            self.headers = headers
            self.body = body
            self.final = final
        }
    }

    private struct LocalServerInvocation: Sendable {
        let requestId: String
        let request: ByteBuffer

        func acceptedResponse() -> LocalServerResponse {

            // required headers
            let headers = HTTPHeaders([
                (AmazonHeaders.requestID, self.requestId),
                (
                    AmazonHeaders.invokedFunctionARN,
                    "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"
                ),
                (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
                (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
            ])

            return LocalServerResponse(
                id: self.requestId,
                status: .accepted,
                headers: headers,
                body: self.request,
                final: true
            )
        }
    }
}

extension Result {
    var maybeError: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
#endif
