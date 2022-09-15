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
import NIOCore
import XCTest

class LambdaHandlerTest: XCTestCase {
    #if compiler(>=5.5) && canImport(_Concurrency)

    // MARK: - LambdaHandler

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testBootstrapSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct TestBootstrapHandler: LambdaHandler {
            var initialized = false

            init() {}
            init(context: LambdaInitializationContext) async throws {
                XCTAssertFalse(self.initialized)
                try await Task.sleep(nanoseconds: 100 * 1000 * 1000) // 0.1 seconds
                self.initialized = true
            }

            func handle(_ event: String, context: LambdaContext) async throws -> String {
                event
            }
        }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: TestBootstrapHandler.self),
            shouldHaveRun: maxTimes
        )
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testBootstrapFailure() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct TestBootstrapHandler: LambdaHandler {
            var initialized = false

            init() {}
            init(context: LambdaInitializationContext) async throws {
                XCTAssertFalse(self.initialized)
                try await Task.sleep(nanoseconds: 100 * 1000 * 1000) // 0.1 seconds
                throw TestError("kaboom")
            }

            func handle(_ event: String, context: LambdaContext) async throws {
                XCTFail("How can this be called if init failed")
            }
        }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: TestBootstrapHandler.self),
            shouldFailWithError: TestError("kaboom")
        )
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testHandlerSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            func handle(_ event: String, context: LambdaContext) async throws -> String {
                event
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: Handler.self),
            shouldHaveRun: maxTimes
        )
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testVoidHandlerSuccess() {
        let server = MockLambdaServer(behavior: Behavior(result: .success(nil)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            func handle(_ event: String, context: LambdaContext) async throws {}
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))

        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: Handler.self),
            shouldHaveRun: maxTimes
        )
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func testHandlerFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom"))))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            func handle(_ event: String, context: LambdaContext) async throws -> String {
                throw TestError("boom")
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: Handler.self),
            shouldHaveRun: maxTimes
        )
    }
    #endif

    // MARK: - EventLoopLambdaHandler

    func testEventLoopSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias Event = String
            typealias Output = String

            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: String, context: LambdaContext) -> EventLoopFuture<String> {
                context.eventLoop.makeSucceededFuture(event)
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: Handler.self),
            shouldHaveRun: maxTimes
        )
    }

    func testVoidEventLoopSuccess() {
        let server = MockLambdaServer(behavior: Behavior(result: .success(nil)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias Event = String
            typealias Output = Void

            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: String, context: LambdaContext) -> EventLoopFuture<Void> {
                context.eventLoop.makeSucceededFuture(())
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: Handler.self),
            shouldHaveRun: maxTimes
        )
    }

    func testEventLoopFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom"))))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias Event = String
            typealias Output = String

            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: String, context: LambdaContext) -> EventLoopFuture<String> {
                context.eventLoop.makeFailedFuture(TestError("boom"))
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        assertLambdaRuntimeResult(
            try Lambda.run(configuration: configuration, handlerType: Handler.self),
            shouldHaveRun: maxTimes
        )
    }

    func testEventLoopBootstrapFailure() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias Event = String
            typealias Output = String

            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeFailedFuture(TestError("kaboom"))
            }

            func handle(_ event: String, context: LambdaContext) -> EventLoopFuture<String> {
                XCTFail("Must never be called")
                return context.eventLoop.makeFailedFuture(TestError("boom"))
            }
        }

        assertLambdaRuntimeResult(
            try Lambda.run(configuration: .init(), handlerType: Handler.self),
            shouldFailWithError: TestError("kaboom")
        )
    }
}

private struct Behavior: LambdaServerBehavior {
    let requestId: String
    let event: String
    let result: Result<String?, TestError>

    init(requestId: String = UUID().uuidString, event: String = "hello", result: Result<String?, TestError> = .success("hello")) {
        self.requestId = requestId
        self.event = event
        self.result = result
    }

    func getInvocation() -> GetInvocationResult {
        .success((requestId: self.requestId, event: self.event))
    }

    func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
        XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
        switch self.result {
        case .success(let expected):
            XCTAssertEqual(expected, response, "expecting response to match")
            return .success(())
        case .failure:
            XCTFail("unexpected to fail, but succeeded with: \(response ?? "undefined")")
            return .failure(.internalServerError)
        }
    }

    func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
        XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
        switch self.result {
        case .success:
            XCTFail("unexpected to succeed, but failed with: \(error)")
            return .failure(.internalServerError)
        case .failure(let expected):
            XCTAssertEqual(expected.description, error.errorMessage, "expecting error to match")
            return .success(())
        }
    }

    func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
        XCTFail("should not report init error")
        return .failure(.internalServerError)
    }
}
