//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaRuntimeCore
import NIOCore
import NIOEmbedded
import NIOHTTP1
import XCTest

final class ControlPlaneRequestEncoderTests: XCTestCase {
    let host = "192.168.0.1"

    var client: EmbeddedChannel!
    var server: EmbeddedChannel!

    override func setUp() {
        self.client = EmbeddedChannel(handler: ControlPlaneRequestEncoderHandler(host: self.host))
        self.server = EmbeddedChannel(handlers: [
            ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes)),
            NIOHTTPServerRequestAggregator(maxContentLength: 1024 * 1024),
        ])
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.client.finish(acceptAlreadyClosed: false))
        XCTAssertNoThrow(try self.server.finish(acceptAlreadyClosed: false))
        self.client = nil
        self.server = nil
    }

    func testNextRequest() {
        var request: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(request = try self.sendRequest(.next))

        XCTAssertEqual(request?.head.isKeepAlive, true)
        XCTAssertEqual(request?.head.method, .GET)
        XCTAssertEqual(request?.head.uri, "/2018-06-01/runtime/invocation/next")
        XCTAssertEqual(request?.head.version, .http1_1)
        XCTAssertEqual(request?.head.headers["host"], [self.host])
        XCTAssertEqual(request?.head.headers["user-agent"], ["Swift-Lambda/Unknown"])

        XCTAssertNil(try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
    }

    func testPostInvocationSuccessWithoutBody() {
        let requestID = LambdaRequestID()
        var request: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(request = try self.sendRequest(.invocationResponse(requestID, nil)))

        XCTAssertEqual(request?.head.isKeepAlive, true)
        XCTAssertEqual(request?.head.method, .POST)
        XCTAssertEqual(request?.head.uri, "/2018-06-01/runtime/invocation/\(requestID)/response")
        XCTAssertEqual(request?.head.version, .http1_1)
        XCTAssertEqual(request?.head.headers["host"], [self.host])
        XCTAssertEqual(request?.head.headers["user-agent"], ["Swift-Lambda/Unknown"])
        XCTAssertEqual(request?.head.headers["content-length"], ["0"])

        XCTAssertNil(try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
    }

    func testPostInvocationSuccessWithBody() {
        let requestID = LambdaRequestID()
        let payload = ByteBuffer(string: "hello swift lambda!")

        var request: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(request = try self.sendRequest(.invocationResponse(requestID, payload)))

        XCTAssertEqual(request?.head.isKeepAlive, true)
        XCTAssertEqual(request?.head.method, .POST)
        XCTAssertEqual(request?.head.uri, "/2018-06-01/runtime/invocation/\(requestID)/response")
        XCTAssertEqual(request?.head.version, .http1_1)
        XCTAssertEqual(request?.head.headers["host"], [self.host])
        XCTAssertEqual(request?.head.headers["user-agent"], ["Swift-Lambda/Unknown"])
        XCTAssertEqual(request?.head.headers["content-length"], ["\(payload.readableBytes)"])
        XCTAssertEqual(request?.body, payload)

        XCTAssertNil(try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
    }

    func testPostInvocationErrorWithBody() {
        let requestID = LambdaRequestID()
        let error = ErrorResponse(errorType: "SomeError", errorMessage: "An error happened")
        var request: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(request = try self.sendRequest(.invocationError(requestID, error)))

        XCTAssertEqual(request?.head.isKeepAlive, true)
        XCTAssertEqual(request?.head.method, .POST)
        XCTAssertEqual(request?.head.uri, "/2018-06-01/runtime/invocation/\(requestID)/error")
        XCTAssertEqual(request?.head.version, .http1_1)
        XCTAssertEqual(request?.head.headers["host"], [self.host])
        XCTAssertEqual(request?.head.headers["user-agent"], ["Swift-Lambda/Unknown"])
        XCTAssertEqual(request?.head.headers["lambda-runtime-function-error-type"], ["Unhandled"])
        let expectedBody = #"{"errorType":"SomeError","errorMessage":"An error happened"}"#

        XCTAssertEqual(request?.head.headers["content-length"], ["\(expectedBody.utf8.count)"])
        XCTAssertEqual(try request?.body?.getString(at: 0, length: XCTUnwrap(request?.body?.readableBytes)),
                       expectedBody)

        XCTAssertNil(try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
    }

    func testPostStartupError() {
        let error = ErrorResponse(errorType: "StartupError", errorMessage: "Urgh! Startup failed. 😨")
        var request: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(request = try self.sendRequest(.initializationError(error)))

        XCTAssertEqual(request?.head.isKeepAlive, true)
        XCTAssertEqual(request?.head.method, .POST)
        XCTAssertEqual(request?.head.uri, "/2018-06-01/runtime/init/error")
        XCTAssertEqual(request?.head.version, .http1_1)
        XCTAssertEqual(request?.head.headers["host"], [self.host])
        XCTAssertEqual(request?.head.headers["user-agent"], ["Swift-Lambda/Unknown"])
        XCTAssertEqual(request?.head.headers["lambda-runtime-function-error-type"], ["Unhandled"])
        let expectedBody = #"{"errorType":"StartupError","errorMessage":"Urgh! Startup failed. 😨"}"#
        XCTAssertEqual(request?.head.headers["content-length"], ["\(expectedBody.utf8.count)"])
        XCTAssertEqual(try request?.body?.getString(at: 0, length: XCTUnwrap(request?.body?.readableBytes)),
                       expectedBody)

        XCTAssertNil(try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
    }

    func testMultipleNextAndResponseSuccessRequests() {
        for _ in 0 ..< 1000 {
            var nextRequest: NIOHTTPServerRequestFull?
            XCTAssertNoThrow(nextRequest = try self.sendRequest(.next))
            XCTAssertEqual(nextRequest?.head.method, .GET)
            XCTAssertEqual(nextRequest?.head.uri, "/2018-06-01/runtime/invocation/next")

            let requestID = LambdaRequestID()
            let payload = ByteBuffer(string: "hello swift lambda!")
            var successRequest: NIOHTTPServerRequestFull?
            XCTAssertNoThrow(successRequest = try self.sendRequest(.invocationResponse(requestID, payload)))
            XCTAssertEqual(successRequest?.head.method, .POST)
            XCTAssertEqual(successRequest?.head.uri, "/2018-06-01/runtime/invocation/\(requestID)/response")
        }
    }

    func sendRequest(_ request: ControlPlaneRequest) throws -> NIOHTTPServerRequestFull? {
        try self.client.writeOutbound(request)
        while let part = try self.client.readOutbound(as: ByteBuffer.self) {
            XCTAssertNoThrow(try self.server.writeInbound(part))
        }
        return try self.server.readInbound(as: NIOHTTPServerRequestFull.self)
    }
}

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
