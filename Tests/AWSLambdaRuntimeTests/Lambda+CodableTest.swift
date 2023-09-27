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
import NIOCore
import NIOFoundationCompat
import NIOPosix
import XCTest

class CodableLambdaTest: XCTestCase {
    var eventLoopGroup: EventLoopGroup!
    let allocator = ByteBufferAllocator()

    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.eventLoopGroup.syncShutdownGracefully())
    }

    func testCodableVoidEventLoopFutureHandler() {
        struct Handler: EventLoopLambdaHandler {
            var expected: Request?

            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: Request, context: LambdaContext) -> EventLoopFuture<Void> {
                XCTAssertEqual(event, self.expected)
                return context.eventLoop.makeSucceededVoidFuture()
            }
        }

        let context = self.newContext()
        let request = Request(requestId: UUID().uuidString)

        let handler = CodableEventLoopLambdaHandler(
            handler: Handler(expected: request),
            allocator: context.allocator
        )

        var inputBuffer = context.allocator.buffer(capacity: 1024)
        XCTAssertNoThrow(try JSONEncoder().encode(request, into: &inputBuffer))
        var outputBuffer: ByteBuffer?
        XCTAssertNoThrow(outputBuffer = try handler.handle(inputBuffer, context: context).wait())
        XCTAssertEqual(outputBuffer?.readableBytes, 0)
    }

    func testCodableEventLoopFutureHandler() {
        struct Handler: EventLoopLambdaHandler {
            var expected: Request?

            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: Request, context: LambdaContext) -> EventLoopFuture<Response> {
                XCTAssertEqual(event, self.expected)
                return context.eventLoop.makeSucceededFuture(Response(requestId: event.requestId))
            }
        }

        let context = self.newContext()
        let request = Request(requestId: UUID().uuidString)
        var response: Response?

        let handler = CodableEventLoopLambdaHandler(
            handler: Handler(expected: request),
            allocator: context.allocator
        )

        var inputBuffer = context.allocator.buffer(capacity: 1024)
        XCTAssertNoThrow(try JSONEncoder().encode(request, into: &inputBuffer))
        var outputBuffer: ByteBuffer?
        XCTAssertNoThrow(outputBuffer = try handler.handle(inputBuffer, context: context).wait())
        XCTAssertNoThrow(response = try JSONDecoder().decode(Response.self, from: XCTUnwrap(outputBuffer)))
        XCTAssertEqual(response?.requestId, request.requestId)
    }

    func testCodableVoidHandler() async throws {
        struct Handler: LambdaHandler {
            init(context: AWSLambdaRuntimeCore.LambdaInitializationContext) async throws {}

            var expected: Request?

            func handle(_ event: Request, context: LambdaContext) async throws {
                XCTAssertEqual(event, self.expected)
            }
        }

        let context = self.newContext()
        let request = Request(requestId: UUID().uuidString)

        var underlying = try await Handler(context: self.newInitContext())
        underlying.expected = request
        let handler = NonFactoryCodableLambdaHandler(
            handler: underlying,
            allocator: context.allocator
        )

        var inputBuffer = context.allocator.buffer(capacity: 1024)
        XCTAssertNoThrow(try JSONEncoder().encode(request, into: &inputBuffer))
        var outputBuffer: ByteBuffer?
        XCTAssertNoThrow(outputBuffer = try handler.handle(inputBuffer, context: context).wait())
        XCTAssertEqual(outputBuffer?.readableBytes, 0)
    }

    func testCodableHandler() async throws {
        struct Handler: LambdaHandler {
            init(context: AWSLambdaRuntimeCore.LambdaInitializationContext) async throws {}

            var expected: Request?

            func handle(_ event: Request, context: LambdaContext) async throws -> Response {
                XCTAssertEqual(event, self.expected)
                return Response(requestId: event.requestId)
            }
        }

        let context = self.newContext()
        let request = Request(requestId: UUID().uuidString)
        var response: Response?

        var underlying = try await Handler(context: self.newInitContext())
        underlying.expected = request
        let handler = NonFactoryCodableLambdaHandler(
            handler: underlying,
            allocator: context.allocator
        )

        var inputBuffer = context.allocator.buffer(capacity: 1024)
        XCTAssertNoThrow(try JSONEncoder().encode(request, into: &inputBuffer))

        var outputBuffer: ByteBuffer?
        XCTAssertNoThrow(outputBuffer = try handler.handle(inputBuffer, context: context).wait())
        XCTAssertNoThrow(response = try JSONDecoder().decode(Response.self, from: XCTUnwrap(outputBuffer)))
        XCTAssertNoThrow(try handler.handle(inputBuffer, context: context).wait())
        XCTAssertEqual(response?.requestId, request.requestId)
    }

    // convenience method
    func newContext() -> LambdaContext {
        LambdaContext(
            requestID: UUID().uuidString,
            traceID: "abc123",
            invokedFunctionARN: "aws:arn:",
            deadline: .now() + .seconds(3),
            cognitoIdentity: nil,
            clientContext: nil,
            logger: Logger(label: "test"),
            eventLoop: self.eventLoopGroup.next(),
            allocator: ByteBufferAllocator()
        )
    }

    func newInitContext() -> LambdaInitializationContext {
        LambdaInitializationContext(
            logger: Logger(label: "test"),
            eventLoop: self.eventLoopGroup.next(),
            allocator: ByteBufferAllocator(),
            terminator: LambdaTerminator()
        )
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
