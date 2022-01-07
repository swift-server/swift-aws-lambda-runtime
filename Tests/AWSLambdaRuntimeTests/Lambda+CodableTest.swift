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
        let request = Request(requestId: UUID().uuidString)
        var inputBuffer: ByteBuffer?
        var outputBuffer: ByteBuffer?

        struct Handler: EventLoopLambdaHandler {
            typealias Event = Request
            typealias Output = Void

            var expected: Request?

            static func makeHandler(context: Lambda.InitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: Request, context: LambdaContext) -> EventLoopFuture<Void> {
                XCTAssertEqual(event, self.expected)
                return context.eventLoop.makeSucceededVoidFuture()
            }
        }

        let handler = Handler(expected: request)

        XCTAssertNoThrow(inputBuffer = try JSONEncoder().encode(request, using: self.allocator))
        XCTAssertNoThrow(outputBuffer = try handler.handle(XCTUnwrap(inputBuffer), context: self.newContext()).wait())
        XCTAssertNil(outputBuffer)
    }

    func testCodableEventLoopFutureHandler() {
        let request = Request(requestId: UUID().uuidString)
        var inputBuffer: ByteBuffer?
        var outputBuffer: ByteBuffer?
        var response: Response?

        struct Handler: EventLoopLambdaHandler {
            typealias Event = Request
            typealias Output = Response

            var expected: Request?

            static func makeHandler(context: Lambda.InitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: Request, context: LambdaContext) -> EventLoopFuture<Response> {
                XCTAssertEqual(event, self.expected)
                return context.eventLoop.makeSucceededFuture(Response(requestId: event.requestId))
            }
        }

        let handler = Handler(expected: request)

        XCTAssertNoThrow(inputBuffer = try JSONEncoder().encode(request, using: self.allocator))
        XCTAssertNoThrow(outputBuffer = try handler.handle(XCTUnwrap(inputBuffer), context: self.newContext()).wait())
        XCTAssertNoThrow(response = try JSONDecoder().decode(Response.self, from: XCTUnwrap(outputBuffer)))
        XCTAssertEqual(response?.requestId, request.requestId)
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testCodableVoidHandler() {
        struct Handler: LambdaHandler {
            typealias Event = Request
            typealias Output = Void

            var expected: Request?

            init(context: Lambda.InitializationContext) async throws {}

            func handle(_ event: Request, context: LambdaContext) async throws {
                XCTAssertEqual(event, self.expected)
            }
        }

        XCTAsyncTest {
            let request = Request(requestId: UUID().uuidString)
            var inputBuffer: ByteBuffer?
            var outputBuffer: ByteBuffer?

            var handler = try await Handler(context: self.newInitContext())
            handler.expected = request

            XCTAssertNoThrow(inputBuffer = try JSONEncoder().encode(request, using: self.allocator))
            XCTAssertNoThrow(outputBuffer = try handler.handle(XCTUnwrap(inputBuffer), context: self.newContext()).wait())
            XCTAssertNil(outputBuffer)
        }
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testCodableHandler() {
        struct Handler: LambdaHandler {
            typealias Event = Request
            typealias Output = Response

            var expected: Request?

            init(context: Lambda.InitializationContext) async throws {}

            func handle(_ event: Request, context: LambdaContext) async throws -> Response {
                XCTAssertEqual(event, self.expected)
                return Response(requestId: event.requestId)
            }
        }

        XCTAsyncTest {
            let request = Request(requestId: UUID().uuidString)
            var response: Response?
            var inputBuffer: ByteBuffer?
            var outputBuffer: ByteBuffer?

            var handler = try await Handler(context: self.newInitContext())
            handler.expected = request

            XCTAssertNoThrow(inputBuffer = try JSONEncoder().encode(request, using: self.allocator))
            XCTAssertNoThrow(outputBuffer = try handler.handle(XCTUnwrap(inputBuffer), context: self.newContext()).wait())
            XCTAssertNoThrow(response = try JSONDecoder().decode(Response.self, from: XCTUnwrap(outputBuffer)))
            XCTAssertEqual(response?.requestId, request.requestId)
        }
    }
    #endif

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

    func newInitContext() -> Lambda.InitializationContext {
        Lambda.InitializationContext(
            logger: Logger(label: "test"),
            eventLoop: self.eventLoopGroup.next(),
            allocator: ByteBufferAllocator()
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

#if compiler(>=5.5) && canImport(_Concurrency)
// NOTE: workaround until we have async test support on linux
//         https://github.com/apple/swift-corelibs-xctest/pull/326
extension XCTestCase {
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func XCTAsyncTest(
        expectationDescription: String = "Async operation",
        timeout: TimeInterval = 3,
        file: StaticString = #file,
        line: Int = #line,
        operation: @escaping () async throws -> Void
    ) {
        let expectation = self.expectation(description: expectationDescription)
        Task {
            do { try await operation() }
            catch {
                XCTFail("Error thrown while executing async function @ \(file):\(line): \(error)")
                Thread.callStackSymbols.forEach { print($0) }
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: timeout)
    }
}
#endif
