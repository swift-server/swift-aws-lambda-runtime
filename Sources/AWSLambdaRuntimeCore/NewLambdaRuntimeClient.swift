//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import _NIOBase64

final actor NewLambdaRuntimeClient: LambdaRuntimeClientProtocol {
    nonisolated let unownedExecutor: UnownedSerialExecutor

    struct Configuration {
        var ip: String
        var port: Int
    }

    struct Writer: LambdaResponseStreamWriter {
        private var runtimeClient: NewLambdaRuntimeClient

        fileprivate init(runtimeClient: NewLambdaRuntimeClient) {
            self.runtimeClient = runtimeClient
        }

        func write(_ buffer: NIOCore.ByteBuffer) async throws {
            try await self.runtimeClient.write(buffer)
        }

        func finish() async throws {
            try await self.runtimeClient.writeAndFinish(nil)
        }

        func writeAndFinish(_ buffer: NIOCore.ByteBuffer) async throws {
            try await self.runtimeClient.writeAndFinish(buffer)
        }

        func reportError(_ error: any Error) async throws {
            try await self.runtimeClient.reportError(error)
        }
    }

    private enum ConnectionState {
        case disconnected
        case connecting([CheckedContinuation<LambdaChannelHandler<NewLambdaRuntimeClient>, any Error>])
        case connected(Channel, LambdaChannelHandler<NewLambdaRuntimeClient>)
    }

    enum LambdaState {
        /// this is the "normal" state. Transitions to `waitingForNextInvocation`
        case idle(previousRequestID: String?)
        /// this is the state while we wait for an invocation. A next call is running.
        /// Transitions to `waitingForResponse`
        case waitingForNextInvocation
        /// The invocation was forwarded to the handler and we wait for a response.
        /// Transitions to `sendingResponse` or `sentResponse`.
        case waitingForResponse(requestID: String)
        case sendingResponse(requestID: String)
        case sentResponse(requestID: String)
    }

    private let eventLoop: any EventLoop
    private let logger: Logger
    private let configuration: Configuration
    private var connectionState: ConnectionState = .disconnected
    private var lambdaState: LambdaState = .idle(previousRequestID: nil)

    static func withRuntimeClient<Result>(
        configuration: Configuration,
        eventLoop: any EventLoop,
        logger: Logger,
        _ body: (NewLambdaRuntimeClient) async throws -> Result
    ) async throws -> Result {
        let runtime = NewLambdaRuntimeClient(configuration: configuration, eventLoop: eventLoop, logger: logger)
        let result: Swift.Result<Result, any Error>
        do {
            result = .success(try await body(runtime))
        } catch {
            result = .failure(error)
        }

        //try? await runtime.close()
        return try result.get()
    }

    private init(configuration: Configuration, eventLoop: any EventLoop, logger: Logger) {
        self.unownedExecutor = eventLoop.executor.asUnownedSerialExecutor()
        self.configuration = configuration
        self.eventLoop = eventLoop
        self.logger = logger
    }

    func nextInvocation() async throws -> (Invocation, Writer) {
        switch self.lambdaState {
        case .idle:
            self.lambdaState = .waitingForNextInvocation
            let handler = try await self.makeOrGetConnection()
            let invocation = try await handler.nextInvocation()
            guard case .waitingForNextInvocation = self.lambdaState else {
                fatalError("Invalid state: \(self.lambdaState)")
            }
            self.lambdaState = .waitingForResponse(requestID: invocation.metadata.requestID)
            return (invocation, Writer(runtimeClient: self))

        case .waitingForNextInvocation,
            .waitingForResponse,
            .sendingResponse,
            .sentResponse:
            fatalError("Invalid state: \(self.lambdaState)")
        }

    }

    private func write(_ buffer: NIOCore.ByteBuffer) async throws {
        switch self.lambdaState {
        case .idle, .sentResponse:
            throw NewLambdaRuntimeError(code: .writeAfterFinishHasBeenSent)

        case .waitingForNextInvocation:
            fatalError("Invalid state: \(self.lambdaState)")

        case .waitingForResponse(let requestID):
            self.lambdaState = .sendingResponse(requestID: requestID)
            fallthrough

        case .sendingResponse(let requestID):
            let handler = try await self.makeOrGetConnection()
            guard case .sendingResponse(requestID) = self.lambdaState else {
                fatalError("Invalid state: \(self.lambdaState)")
            }
            return try await handler.writeResponseBodyPart(buffer, requestID: requestID)
        }
    }

    private func writeAndFinish(_ buffer: NIOCore.ByteBuffer?) async throws {
        switch self.lambdaState {
        case .idle, .sentResponse:
            throw NewLambdaRuntimeError(code: .finishAfterFinishHasBeenSent)

        case .waitingForNextInvocation:
            fatalError("Invalid state: \(self.lambdaState)")

        case .waitingForResponse(let requestID):
            fallthrough

        case .sendingResponse(let requestID):
            self.lambdaState = .sentResponse(requestID: requestID)
            let handler = try await self.makeOrGetConnection()
            guard case .sentResponse(requestID) = self.lambdaState else {
                fatalError("Invalid state: \(self.lambdaState)")
            }
            try await handler.finishResponseRequest(finalData: buffer, requestID: requestID)
            guard case .sentResponse(requestID) = self.lambdaState else {
                fatalError("Invalid state: \(self.lambdaState)")
            }
            self.lambdaState = .idle(previousRequestID: requestID)
        }
    }

    private func reportError(_ error: any Error) async throws {
        switch self.lambdaState {
        case .idle, .waitingForNextInvocation, .sentResponse:
            fatalError("Invalid state: \(self.lambdaState)")

        case .waitingForResponse(let requestID):
            fallthrough

        case .sendingResponse(let requestID):
            self.lambdaState = .sentResponse(requestID: requestID)
            let handler = try await self.makeOrGetConnection()
            guard case .sentResponse(requestID) = self.lambdaState else {
                fatalError("Invalid state: \(self.lambdaState)")
            }
            try await handler.reportError(error, requestID: requestID)
            guard case .sentResponse(requestID) = self.lambdaState else {
                fatalError("Invalid state: \(self.lambdaState)")
            }
            self.lambdaState = .idle(previousRequestID: requestID)
        }
    }

    private func channelClosed(_ channel: any Channel) {
        // TODO: Fill out
    }

    private func makeOrGetConnection() async throws -> LambdaChannelHandler<NewLambdaRuntimeClient> {
        switch self.connectionState {
        case .disconnected:
            self.connectionState = .connecting([])
            break
        case .connecting(var array):
            // Since we do get sequential invocations this case normally should never be hit.
            // We'll support it anyway.
            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<LambdaChannelHandler<NewLambdaRuntimeClient>, any Error>) in
                array.append(continuation)
                self.connectionState = .connecting(array)
            }
        case .connected(_, let handler):
            return handler
        }

        let bootstrap = ClientBootstrap(group: self.eventLoop)
            .channelInitializer { channel in
                do {
                    try channel.pipeline.syncOperations.addHTTPClientHandlers()
                    // Lambda quotas... An invocation payload is maximal 6MB in size:
                    //   https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
                    try channel.pipeline.syncOperations.addHandler(
                        NIOHTTPClientResponseAggregator(maxContentLength: 6 * 1024 * 1024)
                    )
                    try channel.pipeline.syncOperations.addHandler(
                        LambdaChannelHandler(delegate: self, logger: self.logger)
                    )
                    return channel.eventLoop.makeSucceededFuture(())
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }

        do {
            // connect directly via socket address to avoid happy eyeballs (perf)
            let address = try SocketAddress(ipAddress: self.configuration.ip, port: self.configuration.port)
            let channel = try await bootstrap.connect(to: address).get()
            let handler = try channel.pipeline.syncOperations.handler(
                type: LambdaChannelHandler<NewLambdaRuntimeClient>.self
            )
            channel.closeFuture.whenComplete { result in
                self.eventLoop.preconditionInEventLoop()
                self.assumeIsolated { runtimeClient in
                    runtimeClient.channelClosed(channel)
                }
            }

            switch self.connectionState {
            case .disconnected, .connected:
                fatalError("Unexpected state: \(self.connectionState)")

            case .connecting(let array):
                self.connectionState = .connected(channel, handler)
                defer {
                    for continuation in array {
                        continuation.resume(returning: handler)
                    }
                }
                return handler
            }
        } catch {
            switch self.connectionState {
            case .disconnected, .connected:
                fatalError("Unexpected state: \(self.connectionState)")

            case .connecting(let array):
                self.connectionState = .disconnected
                defer {
                    for continuation in array {
                        continuation.resume(throwing: error)
                    }
                }
                throw error
            }
        }
    }
}

extension NewLambdaRuntimeClient: LambdaChannelHandlerDelegate {
    nonisolated func connectionErrorHappened(_ error: any Error, channel: any Channel) {

    }

    nonisolated func connectionWillClose(channel: any Channel) {

    }
}

private protocol LambdaChannelHandlerDelegate {
    func connectionWillClose(channel: any Channel)
    func connectionErrorHappened(_ error: any Error, channel: any Channel)
}

private final class LambdaChannelHandler<Delegate> {
    let nextInvocationPath = Consts.invocationURLPrefix + Consts.getNextInvocationURLSuffix

    enum State {
        case disconnected
        case connected(ChannelHandlerContext, LambdaState)

        enum LambdaState {
            /// this is the "normal" state. Transitions to `waitingForNextInvocation`
            case idle
            /// this is the state while we wait for an invocation. A next call is running.
            /// Transitions to `waitingForResponse`
            case waitingForNextInvocation(CheckedContinuation<Invocation, any Error>)
            /// The invocation was forwarded to the handler and we wait for a response.
            /// Transitions to `sendingResponse` or `sentResponse`.
            case waitingForResponse
            case sendingResponse
            case sentResponse(CheckedContinuation<Void, any Error>)
            case closing
        }
    }

    private var state: State = .disconnected
    private var lastError: Error?
    private var reusableErrorBuffer: ByteBuffer?
    private let logger: Logger
    private let delegate: Delegate

    init(delegate: Delegate, logger: Logger) {
        self.delegate = delegate
        self.logger = logger
    }

    func nextInvocation(isolation: isolated (any Actor)? = #isolation) async throws -> Invocation {
        switch self.state {
        case .connected(let context, .idle):
            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Invocation, any Error>) in
                self.state = .connected(context, .waitingForNextInvocation(continuation))
                self.sendNextRequest(context: context)
            }

        case .connected(_, .closing),
            .connected(_, .sendingResponse),
            .connected(_, .sentResponse),
            .connected(_, .waitingForNextInvocation),
            .connected(_, .waitingForResponse):
            fatalError("Invalid state: \(self.state)")

        case .disconnected:
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneLost)
        }
    }

    func reportError(
        isolation: isolated (any Actor)? = #isolation,
        _ error: any Error,
        requestID: String
    ) async throws {
        switch self.state {
        case .connected(_, .waitingForNextInvocation):
            fatalError("Invalid state: \(self.state)")

        case .connected(let context, .waitingForResponse):
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.state = .connected(context, .sentResponse(continuation))
                self.sendReportErrorRequest(requestID: requestID, error: error, context: context)
            }

        case .connected(let context, .sendingResponse):
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.state = .connected(context, .sentResponse(continuation))
                self.sendResponseStreamingFailure(error: error, context: context)
            }

        case .connected(_, .idle),
            .connected(_, .sentResponse):
            // The final response has already been sent. The only way to report the unhandled error
            // now is to log it. Normally this library never logs higher than debug, we make an
            // exception here, as there is no other way of reporting the error otherwise.
            self.logger.error(
                "Unhandled error after stream has finished",
                metadata: [
                    "lambda_request_id": "\(requestID)",
                    "lambda_error": "\(String(describing: error))",
                ]
            )

        case .disconnected:
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneLost)

        case .connected(_, .closing):
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneGoingAway)
        }
    }

    func writeResponseBodyPart(
        isolation: isolated (any Actor)? = #isolation,
        _ byteBuffer: ByteBuffer,
        requestID: String
    ) async throws {
        switch self.state {
        case .connected(_, .waitingForNextInvocation):
            fatalError("Invalid state: \(self.state)")

        case .connected(let context, .waitingForResponse):
            self.state = .connected(context, .sendingResponse)
            try await self.sendResponseBodyPart(byteBuffer, sendHeadWithRequestID: requestID, context: context)

        case .connected(let context, .sendingResponse):
            try await self.sendResponseBodyPart(byteBuffer, sendHeadWithRequestID: nil, context: context)

        case .connected(_, .idle),
            .connected(_, .sentResponse):
            throw NewLambdaRuntimeError(code: .writeAfterFinishHasBeenSent)

        case .disconnected:
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneLost)

        case .connected(_, .closing):
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneGoingAway)
        }
    }

    func finishResponseRequest(
        isolation: isolated (any Actor)? = #isolation,
        finalData: ByteBuffer?,
        requestID: String
    ) async throws {
        switch self.state {
        case .connected(_, .idle),
            .connected(_, .waitingForNextInvocation):
            fatalError("Invalid state: \(self.state)")

        case .connected(let context, .waitingForResponse):
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.state = .connected(context, .sentResponse(continuation))
                self.sendResponseFinish(finalData, sendHeadWithRequestID: requestID, context: context)
            }

        case .connected(let context, .sendingResponse):
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.state = .connected(context, .sentResponse(continuation))
                self.sendResponseFinish(finalData, sendHeadWithRequestID: nil, context: context)
            }

        case .connected(_, .sentResponse):
            throw NewLambdaRuntimeError(code: .finishAfterFinishHasBeenSent)

        case .disconnected:
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneLost)

        case .connected(_, .closing):
            throw NewLambdaRuntimeError(code: .connectionToControlPlaneGoingAway)
        }
    }

    private func sendResponseBodyPart(
        isolation: isolated (any Actor)? = #isolation,
        _ byteBuffer: ByteBuffer,
        sendHeadWithRequestID: String?,
        context: ChannelHandlerContext
    ) async throws {

        if let requestID = sendHeadWithRequestID {
            // TODO: This feels super expensive. We should be able to make this cheaper. requestIDs are fixed length
            let url = Consts.invocationURLPrefix + "/" + requestID + Consts.postResponseURLSuffix

            let httpRequest = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: url,
                headers: LambdaRuntimeClient.streamingHeaders
            )

            context.write(self.wrapOutboundOut(.head(httpRequest)), promise: nil)
        }

        let future = context.write(self.wrapOutboundOut(.body(.byteBuffer(byteBuffer))))
        context.flush()
        try await future.get()
    }

    private func sendResponseFinish(
        isolation: isolated (any Actor)? = #isolation,
        _ byteBuffer: ByteBuffer?,
        sendHeadWithRequestID: String?,
        context: ChannelHandlerContext
    ) {
        if let requestID = sendHeadWithRequestID {
            // TODO: This feels quite expensive. We should be able to make this cheaper. requestIDs are fixed length
            let url = "\(Consts.invocationURLPrefix)/\(requestID)\(Consts.postResponseURLSuffix)"

            // If we have less than 6MB, we don't want to use the streaming API. If we have more
            // than 6MB we must use the streaming mode.
            let headers: HTTPHeaders =
                if byteBuffer?.readableBytes ?? 0 < 6_000_000 {
                    [
                        "user-agent": "Swift-Lambda/Unknown",
                        "content-length": "\(byteBuffer?.readableBytes ?? 0)",
                    ]
                } else {
                    LambdaRuntimeClient.streamingHeaders
                }

            let httpRequest = HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: url,
                headers: headers
            )

            context.write(self.wrapOutboundOut(.head(httpRequest)), promise: nil)
        }

        if let byteBuffer {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(byteBuffer))), promise: nil)
        }

        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }

    private func sendNextRequest(context: ChannelHandlerContext) {
        let httpRequest = HTTPRequestHead(
            version: .http1_1,
            method: .GET,
            uri: self.nextInvocationPath,
            headers: LambdaRuntimeClient.defaultHeaders
        )

        context.write(self.wrapOutboundOut(.head(httpRequest)), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }

    private func sendReportErrorRequest(requestID: String, error: any Error, context: ChannelHandlerContext) {
        // TODO: This feels quite expensive. We should be able to make this cheaper. requestIDs are fixed length
        let url = "\(Consts.invocationURLPrefix)/\(requestID)\(Consts.postErrorURLSuffix)"

        let httpRequest = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: url,
            headers: LambdaRuntimeClient.errorHeaders
        )

        if self.reusableErrorBuffer == nil {
            self.reusableErrorBuffer = context.channel.allocator.buffer(capacity: 1024)
        } else {
            self.reusableErrorBuffer!.clear()
        }

        let errorResponse = ErrorResponse(errorType: Consts.functionError, errorMessage: "\(error)")
        // TODO: Write this directly into our ByteBuffer
        let bytes = errorResponse.toJSONBytes()
        self.reusableErrorBuffer!.writeBytes(bytes)

        context.write(self.wrapOutboundOut(.head(httpRequest)), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(self.reusableErrorBuffer!))), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }

    private func sendResponseStreamingFailure(error: any Error, context: ChannelHandlerContext) {
        // TODO: Use base64 here
        let trailers: HTTPHeaders = [
            "Lambda-Runtime-Function-Error-Type": "Unhandled",
            "Lambda-Runtime-Function-Error-Body": "Requires base64",
        ]

        context.write(self.wrapOutboundOut(.end(trailers)), promise: nil)
        context.flush()
    }

    func cancelCurrentRequestAndCloseConnection() {
        fatalError("Unimplemented")
    }
}

extension LambdaChannelHandler: ChannelInboundHandler {
    typealias OutboundIn = Never
    typealias InboundIn = NIOHTTPClientResponseFull
    typealias OutboundOut = HTTPClientRequestPart

    func handlerAdded(context: ChannelHandlerContext) {
        if context.channel.isActive {
            self.state = .connected(context, .idle)
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        switch self.state {
        case .disconnected:
            self.state = .connected(context, .idle)
        case .connected:
            break
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)

        switch self.state {
        case .connected(let context, .waitingForNextInvocation(let continuation)):
            do {
                let metadata = try InvocationMetadata(headers: response.head.headers)
                self.state = .connected(context, .waitingForResponse)
                continuation.resume(returning: Invocation(metadata: metadata, event: response.body ?? ByteBuffer()))
            } catch {
                self.state = .connected(context, .closing)
                continuation.resume(
                    throwing: NewLambdaRuntimeError(code: .invocationMissingMetadata, underlying: error)
                )
            }

        case .connected(let context, .sentResponse(let continuation)):
            if response.head.status == .accepted {
                self.state = .connected(context, .idle)
                continuation.resume()
            }

        case .disconnected, .connected(_, _):
            break
        }

        //        // As defined in RFC 7230 Section 6.3:
        //        // HTTP/1.1 defaults to the use of "persistent connections", allowing
        //        // multiple requests and responses to be carried over a single
        //        // connection.  The "close" connection option is used to signal that a
        //        // connection will not persist after the current request/response.  HTTP
        //        // implementations SHOULD support persistent connections.
        //        //
        //        // That's why we only assume the connection shall be closed if we receive
        //        // a "connection = close" header.
        //        let serverCloseConnection =
        //            response.head.headers["connection"].contains(where: { $0.lowercased() == "close" })
        //
        //        let closeConnection = serverCloseConnection || response.head.version != .http1_1
        //
        //        if closeConnection {
        //            // If we were succeeding the request promise here directly and closing the connection
        //            // after succeeding the promise we may run into a race condition:
        //            //
        //            // The lambda runtime will ask for the next work item directly after a succeeded post
        //            // response request. The desire for the next work item might be faster than the attempt
        //            // to close the connection. This will lead to a situation where we try to the connection
        //            // but the next request has already been scheduled on the connection that we want to
        //            // close. For this reason we postpone succeeding the promise until the connection has
        //            // been closed. This codepath will only be hit in the very, very unlikely event of the
        //            // Lambda control plane demanding to close connection. (It's more or less only
        //            // implemented to support http1.1 correctly.) This behavior is ensured with the test
        //            // `LambdaTest.testNoKeepAliveServer`.
        //            self.state = .waitForConnectionClose(httpResponse, promise)
        //            _ = context.channel.close()
        //            return
        //        } else {
        //            self.state = .idle
        //            promise.succeed(httpResponse)
        //        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // pending responses will fail with lastError in channelInactive since we are calling context.close
        self.lastError = error
        context.channel.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // fail any pending responses with last error or assume peer disconnected
        context.fireChannelInactive()

        //        switch self.state {
        //        case .idle:
        //            break
        //
        //        case .running(let promise, let timeout):
        //            self.state = .idle
        //            timeout?.cancel()
        //            promise.fail(self.lastError ?? HTTPClient.Errors.connectionResetByPeer)
        //
        //        case .waitForConnectionClose(let response, let promise):
        //            self.state = .idle
        //            promise.succeed(response)
        //        }
    }
}

private struct RequestCancelEvent {}
