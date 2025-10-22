//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright SwiftAWSLambdaRuntime project authors
// Copyright (c) Amazon.com, Inc. or its affiliates.
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOEmbedded
import NIOHTTP1
import Testing

@testable import AWSLambdaRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct ControlPlaneRequestEncoderTests {
    let host = "192.168.0.1"

    @available(LambdaSwift 2.0, *)
    func createChannels() -> (client: EmbeddedChannel, server: EmbeddedChannel) {
        let client = EmbeddedChannel(handler: ControlPlaneRequestEncoderHandler(host: self.host))
        let server = EmbeddedChannel(handlers: [
            ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes)),
            NIOHTTPServerRequestAggregator(maxContentLength: 1024 * 1024),
        ])
        return (client, server)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testNextRequest() throws {
        let (client, server) = createChannels()
        defer {
            _ = try? client.finish(acceptAlreadyClosed: false)
            _ = try? server.finish(acceptAlreadyClosed: false)
        }

        let request = try sendRequest(.next, client: client, server: server)

        #expect(request?.head.isKeepAlive == true)
        #expect(request?.head.method == .GET)
        #expect(request?.head.uri == "/2018-06-01/runtime/invocation/next")
        #expect(request?.head.version == .http1_1)
        #expect(request?.head.headers["host"] == [self.host])
        #expect(request?.head.headers["user-agent"] == [.userAgent])

        #expect(try server.readInbound(as: NIOHTTPServerRequestFull.self) == nil)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testPostInvocationSuccessWithoutBody() throws {
        let (client, server) = createChannels()
        defer {
            _ = try? client.finish(acceptAlreadyClosed: false)
            _ = try? server.finish(acceptAlreadyClosed: false)
        }

        let requestID = UUID().uuidString
        let request = try sendRequest(.invocationResponse(requestID, nil), client: client, server: server)

        #expect(request?.head.isKeepAlive == true)
        #expect(request?.head.method == .POST)
        #expect(request?.head.uri == "/2018-06-01/runtime/invocation/\(requestID)/response")
        #expect(request?.head.version == .http1_1)
        #expect(request?.head.headers["host"] == [self.host])
        #expect(request?.head.headers["user-agent"] == [.userAgent])
        #expect(request?.head.headers["content-length"] == ["0"])

        #expect(try server.readInbound(as: NIOHTTPServerRequestFull.self) == nil)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testPostInvocationSuccessWithBody() throws {
        let (client, server) = createChannels()
        defer {
            _ = try? client.finish(acceptAlreadyClosed: false)
            _ = try? server.finish(acceptAlreadyClosed: false)
        }

        let requestID = UUID().uuidString
        let payload = ByteBuffer(string: "hello swift lambda!")

        let request = try sendRequest(.invocationResponse(requestID, payload), client: client, server: server)

        #expect(request?.head.isKeepAlive == true)
        #expect(request?.head.method == .POST)
        #expect(request?.head.uri == "/2018-06-01/runtime/invocation/\(requestID)/response")
        #expect(request?.head.version == .http1_1)
        #expect(request?.head.headers["host"] == [self.host])
        #expect(request?.head.headers["user-agent"] == [.userAgent])
        #expect(request?.head.headers["content-length"] == ["\(payload.readableBytes)"])
        #expect(request?.body == payload)

        #expect(try server.readInbound(as: NIOHTTPServerRequestFull.self) == nil)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testPostInvocationErrorWithBody() throws {
        let (client, server) = createChannels()
        defer {
            _ = try? client.finish(acceptAlreadyClosed: false)
            _ = try? server.finish(acceptAlreadyClosed: false)
        }

        let requestID = UUID().uuidString
        let error = ErrorResponse(errorType: "SomeError", errorMessage: "An error happened")
        let request = try sendRequest(.invocationError(requestID, error), client: client, server: server)

        #expect(request?.head.isKeepAlive == true)
        #expect(request?.head.method == .POST)
        #expect(request?.head.uri == "/2018-06-01/runtime/invocation/\(requestID)/error")
        #expect(request?.head.version == .http1_1)
        #expect(request?.head.headers["host"] == [self.host])
        #expect(request?.head.headers["user-agent"] == [.userAgent])
        #expect(request?.head.headers["lambda-runtime-function-error-type"] == ["Unhandled"])
        let expectedBody = #"{"errorType":"SomeError","errorMessage":"An error happened"}"#

        #expect(request?.head.headers["content-length"] == ["\(expectedBody.utf8.count)"])
        let bodyString = request?.body?.getString(at: 0, length: request?.body?.readableBytes ?? 0)
        #expect(bodyString == expectedBody)

        #expect(try server.readInbound(as: NIOHTTPServerRequestFull.self) == nil)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testPostStartupError() throws {
        let (client, server) = createChannels()
        defer {
            _ = try? client.finish(acceptAlreadyClosed: false)
            _ = try? server.finish(acceptAlreadyClosed: false)
        }

        let error = ErrorResponse(errorType: "StartupError", errorMessage: "Urgh! Startup failed. 😨")
        let request = try sendRequest(.initializationError(error), client: client, server: server)

        #expect(request?.head.isKeepAlive == true)
        #expect(request?.head.method == .POST)
        #expect(request?.head.uri == "/2018-06-01/runtime/init/error")
        #expect(request?.head.version == .http1_1)
        #expect(request?.head.headers["host"] == [self.host])
        #expect(request?.head.headers["user-agent"] == [.userAgent])
        #expect(request?.head.headers["lambda-runtime-function-error-type"] == ["Unhandled"])
        let expectedBody = #"{"errorType":"StartupError","errorMessage":"Urgh! Startup failed. 😨"}"#
        #expect(request?.head.headers["content-length"] == ["\(expectedBody.utf8.count)"])
        let bodyString = request?.body?.getString(at: 0, length: request?.body?.readableBytes ?? 0)
        #expect(bodyString == expectedBody)

        #expect(try server.readInbound(as: NIOHTTPServerRequestFull.self) == nil)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testMultipleNextAndResponseSuccessRequests() throws {
        let (client, server) = createChannels()
        defer {
            _ = try? client.finish(acceptAlreadyClosed: false)
            _ = try? server.finish(acceptAlreadyClosed: false)
        }

        for _ in 0..<1000 {
            let nextRequest = try sendRequest(.next, client: client, server: server)
            #expect(nextRequest?.head.method == .GET)
            #expect(nextRequest?.head.uri == "/2018-06-01/runtime/invocation/next")

            let requestID = UUID().uuidString
            let payload = ByteBuffer(string: "hello swift lambda!")
            let successRequest = try sendRequest(
                .invocationResponse(requestID, payload),
                client: client,
                server: server
            )
            #expect(successRequest?.head.method == .POST)
            #expect(successRequest?.head.uri == "/2018-06-01/runtime/invocation/\(requestID)/response")
        }
    }

    @available(LambdaSwift 2.0, *)
    func sendRequest(
        _ request: ControlPlaneRequest,
        client: EmbeddedChannel,
        server: EmbeddedChannel
    ) throws -> NIOHTTPServerRequestFull? {
        try client.writeOutbound(request)
        while let part = try client.readOutbound(as: ByteBuffer.self) {
            try server.writeInbound(part)
        }
        return try server.readInbound(as: NIOHTTPServerRequestFull.self)
    }
}

@available(LambdaSwift 2.0, *)
private final class ControlPlaneRequestEncoderHandler: ChannelOutboundHandler {
    typealias OutboundIn = ControlPlaneRequest
    typealias OutboundOut = ByteBuffer

    private var encoder: ControlPlaneRequestEncoder

    init(host: String) {
        self.encoder = ControlPlaneRequestEncoder(host: host)
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.encoder.writerAdded(context: context)
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.encoder.writerRemoved(context: context)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        self.encoder.writeRequest(self.unwrapOutboundIn(data), context: context, promise: promise)
    }
}
