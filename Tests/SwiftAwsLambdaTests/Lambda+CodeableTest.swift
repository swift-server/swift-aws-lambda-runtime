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

class CodableLambdaTest: XCTestCase {
    func testCallbackSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = Request
            typealias Out = Response

            func handle(context: Lambda.Context, payload: Request, callback: (Result<Response, Error>) -> Void) {
                callback(.success(Response(requestId: payload.requestId)))
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
            typealias In = Request
            typealias Out = Void

            func handle(context: Lambda.Context, payload: Request, callback: (Result<Void, Error>) -> Void) {
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
            typealias In = Request
            typealias Out = Response

            func handle(context: Lambda.Context, payload: Request, callback: (Result<Response, Error>) -> Void) {
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
            typealias In = Request
            typealias Out = Response

            func handle(context: Lambda.Context, payload: Request) -> EventLoopFuture<Response> {
                context.eventLoop.makeSucceededFuture(Response(requestId: payload.requestId))
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
            typealias In = Request
            typealias Out = Void

            func handle(context: Lambda.Context, payload: Request) -> EventLoopFuture<Void> {
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
            typealias In = Request
            typealias Out = Response

            func handle(context: Lambda.Context, payload: Request) -> EventLoopFuture<Response> {
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
        let result = Lambda.run(configuration: configuration) { (_, payload: Request, callback) in
            callback(.success(Response(requestId: payload.requestId)))
        }
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testVoidClosureSuccess() {
        let server = MockLambdaServer(behavior: Behavior(result: .success(nil)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration) { (_, _: Request, callback: (Result<Void, Error>) -> Void) in
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
        let result: Result<Int, Error> = Lambda.run(configuration: configuration) { (_, _: Request, callback: (Result<Response, Error>) -> Void) in
            callback(.failure(TestError("boom")))
        }
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testBootstrapFailure() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = Request
            typealias Out = Response

            init(eventLoop: EventLoop) throws {
                throw TestError("kaboom")
            }

            func handle(context: Lambda.Context, payload: Request, callback: (Result<Response, Error>) -> Void) {
                callback(.failure(TestError("should not be called")))
            }
        }

        let result = Lambda.run(factory: Handler.init)
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }
}

// TODO: taking advantage of the fact we know the serialization is json
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
        guard let payload = try? JSONEncoder().encode(Request(requestId: requestId)) else {
            XCTFail("encoding error")
            return .failure(.internalServerError)
        }
        guard let payloadAsString = String(data: payload, encoding: .utf8) else {
            XCTFail("encoding error")
            return .failure(.internalServerError)
        }
        return .success((requestId: self.requestId, payload: payloadAsString))
    }

    func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
        switch self.result {
        case .success(let expected) where expected != nil:
            guard let data = response?.data(using: .utf8) else {
                XCTFail("decoding error")
                return .failure(.internalServerError)
            }
            guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
                XCTFail("decoding error")
                return .failure(.internalServerError)
            }
            XCTAssertEqual(self.requestId, response.requestId, "expecting requestId to match")
            return .success(())
        case .success(let expected) where expected == nil:
            XCTAssertNil(response)
            return .success(())
        case .failure:
            XCTFail("unexpected to fail, but succeeded with: \(response ?? "undefined")")
            return .failure(.internalServerError)
        default:
            preconditionFailure("invalid state")
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

private struct Request: Codable {
    let requestId: String
    init(requestId: String) {
        self.requestId = requestId
    }
}

private struct Response: Codable {
    let requestId: String
    init(requestId: String) {
        self.requestId = requestId
    }
}
