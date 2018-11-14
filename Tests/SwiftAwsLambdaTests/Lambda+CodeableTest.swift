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

import Foundation

class CodableLambdaTest: XCTestCase {
    func testSuceess() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        let result = Lambda.run(handler: CodableEchoHandler(), maxTimes: maxTimes) // blocking
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehavior()).start().wait()
        let result = Lambda.run(CodableEchoHandler()) // blocking
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode)
    }

    func testClosureSuccess() throws {
        let maxTimes = Int.random(in: 1 ... 10)
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        let result = Lambda.run(closure: { (_: LambdaContext, payload: Req, callback: LambdaCodableCallback<Res>) in
            callback(.success(Res(requestId: payload.requestId)))
        }, maxTimes: maxTimes)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehavior()).start().wait()
        let result = Lambda.run { (_: LambdaContext, payload: Req, callback: LambdaCodableCallback<Res>) in
            callback(.success(Res(requestId: payload.requestId)))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode)
    }
}

private func assertLambdaLifecycleResult(result: LambdaLifecycleResult, shoudHaveRun: Int = 0, shouldFailWithError: Error? = nil) {
    switch result {
    case let .success(count):
        if nil != shouldFailWithError {
            XCTFail("should fail with \(shouldFailWithError!)")
        }
        XCTAssertEqual(shoudHaveRun, count, "should have run \(shoudHaveRun) times")
    case let .failure(error):
        if nil == shouldFailWithError {
            XCTFail("should succeed, but failed with \(error)")
            break // TODO: not sure why the assertion does not break
        }
        XCTAssertEqual(shouldFailWithError?.localizedDescription, error.localizedDescription, "expected error to mactch")
    }
}

// TODO: taking advantage of the fact we know the serialization is json
private class GoodBehavior: LambdaServerBehavior {
    let requestId = NSUUID().uuidString

    func getWork() -> GetWorkResult {
        guard let payload = try? JSONEncoder().encode(Req(requestId: requestId)) else {
            XCTFail("encoding error")
            return .failure(.internalServerError)
        }
        guard let payloadAsString = String(data: payload, encoding: .utf8) else {
            XCTFail("encoding error")
            return .failure(.internalServerError)
        }
        return .success((requestId: requestId, payload: payloadAsString))
    }

    func processResponse(requestId _: String, response: String) -> ProcessResponseResult {
        guard let data = response.data(using: .utf8) else {
            XCTFail("decoding error")
            return .failure(.internalServerError)
        }
        guard let response = try? JSONDecoder().decode(Res.self, from: data) else {
            XCTFail("decoding error")
            return .failure(.internalServerError)
        }
        XCTAssertEqual(requestId, response.requestId, "expecting requestId to match")
        return .success()
    }

    func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
        XCTFail("should not report error")
        return .failure(.internalServerError)
    }
}

private class BadBehavior: LambdaServerBehavior {
    func getWork() -> GetWorkResult {
        return .failure(.internalServerError)
    }

    func processResponse(requestId _: String, response _: String) -> ProcessResponseResult {
        return .failure(.internalServerError)
    }

    func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
        return .failure(.internalServerError)
    }
}

private class Req: Codable {
    let requestId: String
    init(requestId: String) {
        self.requestId = requestId
    }
}

private class Res: Codable {
    let requestId: String
    init(requestId: String) {
        self.requestId = requestId
    }
}

private class CodableEchoHandler: LambdaCodableHandler {
    func handle(context _: LambdaContext, payload: Req, callback: @escaping LambdaCodableCallback<Res>) {
        callback(.success(Res(requestId: payload.requestId)))
    }
}
