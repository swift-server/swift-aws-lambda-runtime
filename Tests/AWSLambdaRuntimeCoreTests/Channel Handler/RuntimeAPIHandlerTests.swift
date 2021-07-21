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
import Logging
import NIO
import NIOFoundationCompat
import NIOHTTP1
import XCTest

final class RuntimeAPIHandlerTest: XCTestCase {
//    var configuration: Lambda.Configuration.RuntimeEngine!
//    var logger: Logger!
//
//    override func setUp() {
//        self.logger = Logger(label: "test")
//        self.configuration = Lambda.Configuration.RuntimeEngine(address: "127.0.0.1:7000")
//    }
//    
//    func testDecodeHTTPAccepted() {
//        let handler = RuntimeAPIHandler(configuration: self.configuration, logger: self.logger)
//        let channel = EmbeddedChannel(handler: handler)
//
//        let expected = Invocation(
//            requestID: UUID().uuidString,
//            deadlineInMillisSinceEpoch: Int64(Date().addingTimeInterval(5).timeIntervalSince1970 * 1000),
//            invokedFunctionARN: "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime",
//            traceID: AmazonHeaders.generateXRayTraceID(),
//            clientContext: "client-context",
//            cognitoIdentity: "cognito-identity")
//        let payload = ByteBuffer(string: "Hello World")
//        
//        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: expected.toHTTPHeaders())
//        let response = NIOHTTPClientResponseFull(head: head, body: payload)
//        
//        XCTAssertNoThrow(try channel.writeInbound(response))
//        XCTAssertEqual(try channel.readInbound(as: RuntimeAPIResponse.self), .next(expected, payload))
//    }
//
//    func testDecodeHTTPNextInvocation() {
//        let handler = RuntimeAPIHandler(configuration: self.configuration, logger: self.logger)
//        let channel = EmbeddedChannel(handler: handler)
//
//        let head = HTTPResponseHead(version: .http1_1, status: .accepted)
//        let response = NIOHTTPClientResponseFull(head: head, body: nil)
//        
//        XCTAssertNoThrow(try channel.writeInbound(response))
//        XCTAssertEqual(try channel.readInbound(as: RuntimeAPIResponse.self), .accepted)
//    }
//
//    
//    func testEncodeGetNext() {
//        let handler = RuntimeAPIHandler(configuration: self.configuration, logger: self.logger)
//        let channel = EmbeddedChannel(handler: handler)
//
//        XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.next))
//        var head: HTTPClientRequestPart?
//        XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
//        guard case .head(let head) = head else {
//            return XCTFail()
//        }
//        XCTAssertEqual(head.version, .http1_1)
//        XCTAssertEqual(head.method, .GET)
//        XCTAssertEqual(head.uri, "/2018-06-01/runtime/invocation/next")
//        XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
//        XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
//        XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
//    }
//
//    func testEncodePostResponse() {
//        let payloads: [ByteBuffer?] = [ByteBuffer(string: "Hello World"), nil]
//
//        let handler = RuntimeAPIHandler(configuration: self.configuration, logger: self.logger)
//        let channel = EmbeddedChannel(handler: handler)
//
//        for payload in payloads {
//            let requestID = UUID().uuidString
//            XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.invocationResponse(requestID, payload)))
//            var head: HTTPClientRequestPart?
//            XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
//            guard case .head(let head) = head else {
//                return XCTFail()
//            }
//            XCTAssertEqual(head.version, .http1_1)
//            XCTAssertEqual(head.method, .POST)
//            XCTAssertEqual(head.uri, "/2018-06-01/runtime/\(requestID)/response")
//            XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
//            XCTAssertEqual(head.headers["content-length"].first, "\(payload?.readableBytes ?? 0)")
//            if let body = payload {
//                XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .body(.byteBuffer(body)))
//            }
//            XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
//            XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
//        }
//    }
//
//    func testEncodePostError() {
//        let handler = RuntimeAPIHandler(configuration: self.configuration, logger: self.logger)
//        let channel = EmbeddedChannel(handler: handler)
//
//        let requestID = UUID().uuidString
//        let response = ErrorResponse(errorType: "Unhandled", errorMessage: "Something has gone terribly wrong")
//        XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.invocationError(requestID, response)))
//        var head: HTTPClientRequestPart?
//        XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
//        guard case .head(let head) = head else {
//            return XCTFail()
//        }
//        XCTAssertEqual(head.version, .http1_1)
//        XCTAssertEqual(head.method, .POST)
//        XCTAssertEqual(head.uri, "/2018-06-01/runtime/\(requestID)/error")
//        XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
//        XCTAssertNotNil(head.headers["content-length"].first)
//        var body: HTTPClientRequestPart?
//        XCTAssertNoThrow(body = try channel.readOutbound(as: HTTPClientRequestPart.self))
//        guard case .body(.byteBuffer(let body)) = body else {
//            return XCTFail()
//        }
//
//        XCTAssertEqual(try JSONDecoder().decode(ErrorResponse.self, from: body), response)
//
//        XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
//        XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
//    }
//
//    func testEncodeInitializationError() {
//        let handler = RuntimeAPIHandler(configuration: self.configuration, logger: self.logger)
//        let channel = EmbeddedChannel(handler: handler)
//
//        let response = ErrorResponse(errorType: "Unhandled", errorMessage: "Something has gone terribly wrong")
//        XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.initializationError(response)))
//        var head: HTTPClientRequestPart?
//        XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
//        guard case .head(let head) = head else {
//            return XCTFail()
//        }
//        XCTAssertEqual(head.version, .http1_1)
//        XCTAssertEqual(head.method, .POST)
//        XCTAssertEqual(head.uri, "/2018-06-01/runtime/init/error")
//        XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
//        XCTAssertNotNil(head.headers["content-length"].first)
//        var body: HTTPClientRequestPart?
//        XCTAssertNoThrow(body = try channel.readOutbound(as: HTTPClientRequestPart.self))
//        guard case .body(.byteBuffer(let body)) = body else {
//            return XCTFail()
//        }
//
//        XCTAssertEqual(try JSONDecoder().decode(ErrorResponse.self, from: body), response)
//
//        XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
//        XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
//    }
}

extension Invocation {
    
    func toHTTPHeaders() -> HTTPHeaders {
        var headers = HTTPHeaders([
            (AmazonHeaders.requestID, self.requestID),
            (AmazonHeaders.invokedFunctionARN, self.invokedFunctionARN),
            (AmazonHeaders.traceID, self.traceID),
            (AmazonHeaders.deadline, String(self.deadlineInMillisSinceEpoch)),
        ])
        
        if let cognitoIdentity = self.cognitoIdentity {
            headers.add(name: AmazonHeaders.cognitoIdentity, value: cognitoIdentity)
        }
        
        if let clientContext = self.clientContext {
            headers.add(name: AmazonHeaders.clientContext, value: clientContext)
        }
        
        return headers
    }
    
}
