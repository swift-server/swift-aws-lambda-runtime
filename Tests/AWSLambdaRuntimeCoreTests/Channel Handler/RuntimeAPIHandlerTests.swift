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
import NIO
import NIOFoundationCompat
import NIOHTTP1
import XCTest

final class RuntimeAPIHandlerTest: XCTestCase {
    
    func testEncodeGetNext() {
        let channel = EmbeddedChannel(handler: RuntimeAPIHandler(host: "127.0.0.1:7000"))
        
        XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.next))
        var head: HTTPClientRequestPart?
        XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
        guard case .head(let head) = head else {
            return XCTFail()
        }
        XCTAssertEqual(head.version, .http1_1)
        XCTAssertEqual(head.method, .GET)
        XCTAssertEqual(head.uri, "/2018-06-01/runtime/invocation/next")
        XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
        XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
        XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
    }
    
    func testEncodePostResponse() {
        let payloads: [ByteBuffer?] = [ByteBuffer(string: "Hello World"), nil]
        
        let channel = EmbeddedChannel(handler: RuntimeAPIHandler(host: "127.0.0.1:7000"))
        for payload in payloads {
            let requestID = UUID().uuidString
            XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.invocationResponse(requestID, payload)))
            var head: HTTPClientRequestPart?
            XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
            guard case .head(let head) = head else {
                return XCTFail()
            }
            XCTAssertEqual(head.version, .http1_1)
            XCTAssertEqual(head.method, .POST)
            XCTAssertEqual(head.uri, "/2018-06-01/runtime/\(requestID)/response")
            XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
            XCTAssertEqual(head.headers["content-length"].first, "\(payload?.readableBytes ?? 0)")
            if let body = payload {
                XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .body(.byteBuffer(body)))
            }
            XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
            XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
        }
    }
        
    func testEncodePostError() {
        let channel = EmbeddedChannel(handler: RuntimeAPIHandler(host: "127.0.0.1:7000"))
        let requestID = UUID().uuidString
        let response = ErrorResponse(errorType: "Unhandled", errorMessage: "Something has gone terribly wrong")
        XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.invocationError(requestID, response)))
        var head: HTTPClientRequestPart?
        XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
        guard case .head(let head) = head else {
            return XCTFail()
        }
        XCTAssertEqual(head.version, .http1_1)
        XCTAssertEqual(head.method, .POST)
        XCTAssertEqual(head.uri, "/2018-06-01/runtime/\(requestID)/error")
        XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
        XCTAssertNotNil(head.headers["content-length"].first)
        var body: HTTPClientRequestPart?
        XCTAssertNoThrow(body = try channel.readOutbound(as: HTTPClientRequestPart.self))
        guard case .body(.byteBuffer(let body)) = body else {
            return XCTFail()
        }
        
        XCTAssertEqual(try JSONDecoder().decode(ErrorResponse.self, from: body), response)
        
        XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
        XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
    }
    
    func testEncodeInitializationError() {
        let channel = EmbeddedChannel(handler: RuntimeAPIHandler(host: "127.0.0.1:7000"))
        let response = ErrorResponse(errorType: "Unhandled", errorMessage: "Something has gone terribly wrong")
        XCTAssertNoThrow(try channel.writeOutbound(RuntimeAPIRequest.initializationError(response)))
        var head: HTTPClientRequestPart?
        XCTAssertNoThrow(head = try channel.readOutbound(as: HTTPClientRequestPart.self))
        guard case .head(let head) = head else {
            return XCTFail()
        }
        XCTAssertEqual(head.version, .http1_1)
        XCTAssertEqual(head.method, .POST)
        XCTAssertEqual(head.uri, "/2018-06-01/runtime/init/error")
        XCTAssertNotNil(head.headers["user-agent"].first?.contains("Swift"))
        XCTAssertNotNil(head.headers["content-length"].first)
        var body: HTTPClientRequestPart?
        XCTAssertNoThrow(body = try channel.readOutbound(as: HTTPClientRequestPart.self))
        guard case .body(.byteBuffer(let body)) = body else {
            return XCTFail()
        }
        
        XCTAssertEqual(try JSONDecoder().decode(ErrorResponse.self, from: body), response)
        
        XCTAssertEqual(try channel.readOutbound(as: HTTPClientRequestPart.self), .end(nil))
        XCTAssertNil(try channel.readOutbound(as: HTTPClientRequestPart.self))
    }
    
}

extension ErrorResponse: Equatable {
    public static func == (lhs: ErrorResponse, rhs: ErrorResponse) -> Bool {
        lhs.errorType == rhs.errorType && lhs.errorMessage == rhs.errorMessage
    }
}
