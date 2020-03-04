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

@testable import SwiftAwsLambda
import XCTest

class StringLambdaTest: XCTestCase {
    func testSuceess() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        let result = Lambda.run(handler: StringEchoHandler(), configuration: configuration)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehavior()).start().wait()
        let result = Lambda.run(handler: StringEchoHandler())
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testClosureSuccess() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        let result = Lambda.run(configuration: configuration) { (_, payload: String, callback) in
            callback(.success(payload))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehavior()).start().wait()
        let result: LambdaLifecycleResult = Lambda.run { (_, payload: String, callback) in
            callback(.success(payload))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }
}

private func assertLambdaLifecycleResult(result: LambdaLifecycleResult, shoudHaveRun: Int = 0, shouldFailWithError: Error? = nil) {
    switch result {
    case .success(let count):
        if shouldFailWithError != nil {
            XCTFail("should fail with \(shouldFailWithError!)")
        }
        XCTAssertEqual(shoudHaveRun, count, "should have run \(shoudHaveRun) times")
    case .failure(let error):
        if shouldFailWithError == nil {
            XCTFail("should succeed, but failed with \(error)")
            break
        }
        XCTAssertEqual(shouldFailWithError?.localizedDescription, error.localizedDescription, "expected error to mactch")
    }
}

private struct GoodBehavior: LambdaServerBehavior {
    let requestId = NSUUID().uuidString
    let payload = "hello"
    func getWork() -> GetWorkResult {
        return .success((requestId: self.requestId, payload: self.payload))
    }

    func processResponse(requestId: String, response: String) -> ProcessResponseResult {
        XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
        XCTAssertEqual(self.payload, response, "expecting response to match")
        return .success
    }

    func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
        XCTFail("should not report error")
        return .failure(.internalServerError)
    }

    func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
        XCTFail("should not report init error")
        return .failure(.internalServerError)
    }
}

private struct BadBehavior: LambdaServerBehavior {
    func getWork() -> GetWorkResult {
        return .failure(.internalServerError)
    }

    func processResponse(requestId: String, response: String) -> ProcessResponseResult {
        return .failure(.internalServerError)
    }

    func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
        return .failure(.internalServerError)
    }

    func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
        return .failure(.internalServerError)
    }
}

private struct StringEchoHandler: LambdaStringHandler {
    func handle(context: LambdaContext, payload: String, callback: @escaping LambdaStringCallback) {
        callback(.success(payload))
    }
}
