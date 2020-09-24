//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaRuntime
@testable import AWSLambdaRuntimeCore
import Logging
import NIO
import NIOFoundationCompat
import XCTest
import Baggage

class CodableLambdaTest: XCTestCase {
    var eventLoopGroup: EventLoopGroup!
    let allocator = ByteBufferAllocator()

    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    override func tearDown() {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }

    func testCodableVoidClosureWrapper() {
        let request = Request(requestId: UUID().uuidString)
        var inputBuffer: ByteBuffer?
        var outputBuffer: ByteBuffer?

        let closureWrapper = CodableVoidClosureWrapper { (_, _: Request, completion) in
            XCTAssertEqual(request, request)
            completion(.success(()))
        }

        XCTAssertNoThrow(inputBuffer = try JSONEncoder().encode(request, using: self.allocator))
        XCTAssertNoThrow(outputBuffer = try closureWrapper.handle(context: self.newContext(), event: XCTUnwrap(inputBuffer)).wait())
        XCTAssertNil(outputBuffer)
    }

    func testCodableClosureWrapper() {
        let request = Request(requestId: UUID().uuidString)
        var inputBuffer: ByteBuffer?
        var outputBuffer: ByteBuffer?
        var response: Response?

        let closureWrapper = CodableClosureWrapper { (_, req: Request, completion: (Result<Response, Error>) -> Void) in
            XCTAssertEqual(request, request)
            completion(.success(Response(requestId: req.requestId)))
        }

        XCTAssertNoThrow(inputBuffer = try JSONEncoder().encode(request, using: self.allocator))
        XCTAssertNoThrow(outputBuffer = try closureWrapper.handle(context: self.newContext(), event: XCTUnwrap(inputBuffer)).wait())
        XCTAssertNoThrow(response = try JSONDecoder().decode(Response.self, from: XCTUnwrap(outputBuffer)))
        XCTAssertEqual(response?.requestId, request.requestId)
    }

    func testBaggageContextInteractions() {
        var context = newContext()
        context.baggage.testValue = "hello"

        context.logger.info("Test")
        XCTAssertEqual(context.baggage.testValue, "hello")
        XCTAssertEqual(context.baggage.lambdaTraceID, "abc123")
        XCTAssertEqual(context.baggage.lambdaTraceID, context.traceID)
        XCTAssertEqual(context.baggage.lambdaRequestID, context.requestID)

        XCTAssertEqual("\(context.logger[metadataKey: "LambdaTraceIDKey"]!)", context.traceID)
        XCTAssertEqual("\(context.logger[metadataKey: "LambdaRequestIDKey"]!)", context.requestID)
        XCTAssertEqual("\(context.logger[metadataKey: "TestKey"]!)", context.baggage.testValue)
    }

    // convenience method
    func newContext() -> Lambda.Context {
        Lambda.Context(requestID: UUID().uuidString,
                       traceID: "abc123",
                       invokedFunctionARN: "aws:arn:",
                       deadline: .now() + .seconds(3),
                       cognitoIdentity: nil,
                       clientContext: nil,
                       logger: Logger(label: "test"),
                       eventLoop: self.eventLoopGroup.next(),
                       allocator: ByteBufferAllocator())
    }
}

private struct Request: Codable, Equatable {
    let requestId: String
    init(requestId: String) {
        self.requestId = requestId
    }
}

private struct Response: Codable, Equatable {
    let requestId: String
    init(requestId: String) {
        self.requestId = requestId
    }
}

extension Baggage {
    enum TestKey: Baggage.Key {
        typealias Value = String

    }
    var testValue: String? {
        get {
            return self[TestKey.self]
        }
        set {
            self[TestKey.self] = newValue
        }
    }
}
