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

@testable import AWSLambdaRuntimeCore
import Logging
import NIO
import NIOHTTP1
import XCTest

class LambdaLifecycleTest: XCTestCase {
    func testShutdownFutureIsFulfilledWithStartUpError() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let eventLoop = eventLoopGroup.next()
        let logger = Logger(label: "TestLogger")
        let testError = TestError("kaboom")
        let lifecycle = Lambda.Lifecycle(eventLoop: eventLoop, logger: logger, factory: {
            $0.makeFailedFuture(testError)
        })

        // eventLoop.submit in this case returns an EventLoopFuture<EventLoopFuture<ByteBufferHandler>>
        // which is why we need `wait().wait()`
        XCTAssertThrowsError(_ = try eventLoop.flatSubmit { lifecycle.start() }.wait()) { error in
            XCTAssertEqual(testError, error as? TestError)
        }

        XCTAssertThrowsError(_ = try lifecycle.shutdownFuture.wait()) { error in
            XCTAssertEqual(testError, error as? TestError)
        }
    }

    func testSyncShutdownIsCalledWhenLambdaShutsdown() {
        struct CallbackLambdaHandler: ByteBufferLambdaHandler {
            let handler: (Lambda.Context, ByteBuffer) -> (EventLoopFuture<ByteBuffer?>)
            let shutdown: () throws -> Void

            init(_ handler: @escaping (Lambda.Context, ByteBuffer) -> (EventLoopFuture<ByteBuffer?>), shutdown: @escaping () throws -> Void) {
                self.handler = handler
                self.shutdown = shutdown
            }

            func handle(context: Lambda.Context, event: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
                self.handler(context, event)
            }

            func syncShutdown() throws {
                try self.shutdown()
            }
        }

        let server = MockLambdaServer(behavior: BadBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        var count = 0
        let handler = CallbackLambdaHandler({ XCTFail("Should not be reached"); return $0.eventLoop.makeSucceededFuture($1) }) {
            count += 1
        }

        let eventLoop = eventLoopGroup.next()
        let logger = Logger(label: "TestLogger")
        let lifecycle = Lambda.Lifecycle(eventLoop: eventLoop, logger: logger, factory: {
            $0.makeSucceededFuture(handler)
        })

        XCTAssertNoThrow(_ = try eventLoop.flatSubmit { lifecycle.start() }.wait())
        XCTAssertThrowsError(_ = try lifecycle.shutdownFuture.wait()) { error in
            XCTAssertEqual(.badStatusCode(HTTPResponseStatus.internalServerError), error as? Lambda.RuntimeError)
        }
        XCTAssertEqual(count, 1)
    }
}

struct BadBehavior: LambdaServerBehavior {
    func getInvocation() -> GetInvocationResult {
        .failure(.internalServerError)
    }

    func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
        XCTFail("should not report a response")
        return .failure(.internalServerError)
    }

    func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
        XCTFail("should not report an error")
        return .failure(.internalServerError)
    }

    func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
        XCTFail("should not report an error")
        return .failure(.internalServerError)
    }
}
