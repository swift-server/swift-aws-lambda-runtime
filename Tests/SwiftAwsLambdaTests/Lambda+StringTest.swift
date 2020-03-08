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
    func testSuceess() throws {
        struct Handler: StringLambdaHandler {
            func handle(context: Lambda.Context, payload: String, callback: @escaping StringLambda.CompletionHandler) {
                callback(.success(payload))
            }
        }
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior()).start().wait()
        let result = Lambda.run(handler: Handler(), configuration: configuration)
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testFailure() throws {
        struct Handler: StringLambdaHandler {
            func handle(context: Lambda.Context, payload: String, callback: @escaping StringLambda.CompletionHandler) {
                callback(.failure(TestError("boom")))
            }
        }
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom")))).start().wait()
        let result = Lambda.run(handler: Handler(), configuration: configuration)
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testPromiseSuccess() throws {
        struct Handler: StringPromiseLambdaHandler {
            func handle(context: Lambda.Context, payload: String, promise: EventLoopPromise<String?>) {
                promise.succeed(payload)
            }
        }
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior()).start().wait()
        let result = Lambda.run(handler: Handler(), configuration: configuration)
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testPromiseFailure() throws {
        struct Handler: StringPromiseLambdaHandler {
            func handle(context: Lambda.Context, payload: String, promise: EventLoopPromise<String?>) {
                promise.fail(TestError("boom"))
            }
        }
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom")))).start().wait()
        let result = Lambda.run(handler: Handler(), configuration: configuration)
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testClosureSuccess() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior()).start().wait()
        let result = Lambda.run(configuration: configuration) { (_, payload: String, callback) in
            callback(.success(payload))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom")))).start().wait()
        let result: Result<Int, Error> = Lambda.run(configuration: configuration) { (_, _: String, callback) in
            callback(.failure(TestError("boom")))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testVoidClosure() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: Behavior(result: .success(nil))).start().wait()
        let result = Lambda.run(configuration: configuration) { (_, _: String, callback) in
            callback(nil)
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
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
        return .success((requestId: self.requestId, payload: self.payload))
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
