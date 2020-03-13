//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@testable import SwiftAwsLambda
import XCTest

class StringLambdaTest: XCTestCase {
    func testCallbackSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = String
            typealias Out = String

            func handle(context: Lambda.Context, payload: String, callback: (Result<String, Error>) -> Void) {
                callback(.success(payload))
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: Handler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testVoidCallbackSuccess() {
        let server = MockLambdaServer(behavior: Behavior(result: .success(nil)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = String
            typealias Out = Void

            func handle(context: Lambda.Context, payload: String, callback: (Result<Void, Error>) -> Void) {
                callback(.success(()))
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: Handler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testCallbackFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom"))))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = String
            typealias Out = String

            func handle(context: Lambda.Context, payload: String, callback: (Result<String, Error>) -> Void) {
                callback(.failure(TestError("boom")))
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: Handler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testEventLoopSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias In = String
            typealias Out = String

            func handle(context: Lambda.Context, payload: String) -> EventLoopFuture<String> {
                context.eventLoop.makeSucceededFuture(payload)
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: Handler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testVoidEventLoopSuccess() {
        let server = MockLambdaServer(behavior: Behavior(result: .success(nil)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias In = String
            typealias Out = Void

            func handle(context: Lambda.Context, payload: String) -> EventLoopFuture<Void> {
                context.eventLoop.makeSucceededFuture(())
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: Handler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testEventLoopFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom"))))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: EventLoopLambdaHandler {
            typealias In = String
            typealias Out = String

            func handle(context: Lambda.Context, payload: String) -> EventLoopFuture<String> {
                context.eventLoop.makeFailedFuture(TestError("boom"))
            }
        }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: Handler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testClosureSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration) { (_, payload: String, callback) in
            callback(.success(payload))
        }
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testVoidClosureSuccess() {
        let server = MockLambdaServer(behavior: Behavior(result: .success(nil)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration) { (_, _: String, callback) in
            callback(.success(()))
        }
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom"))))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result: Result<Int, Error> = Lambda.run(configuration: configuration) { (_, _: String, callback: (Result<String, Error>) -> Void) in
            callback(.failure(TestError("boom")))
        }
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testBootstrapFailure() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = String
            typealias Out = String

            init(eventLoop: EventLoop) throws {
                throw TestError("kaboom")
            }

            func handle(context: Lambda.Context, payload: String, callback: (Result<String, Error>) -> Void) {
                callback(.failure(TestError("should not be called")))
            }
        }

        let result = Lambda.run(factory: Handler.init)
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }
}

private struct Behavior: LambdaServerBehavior {
    let requestId: String
    let payload: String
    let result: Result<String?, TestError>

    init(requestId: String = UUID().uuidString, payload: String = "hello", result: Result<String?, TestError> = .success("hello")) {
        self.requestId = requestId
        self.payload = payload
        self.result = result
    }

    func getWork() -> GetWorkResult {
        .success((requestId: self.requestId, payload: self.payload))
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
