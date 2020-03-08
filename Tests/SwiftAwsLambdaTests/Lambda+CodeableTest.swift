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

class CodableLambdaTest: XCTestCase {
    func testSuccess() {
        let server = MockLambdaServer(behavior: GoodBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(handler: CodableEchoHandler(), configuration: configuration)
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testFailure() {
        let server = MockLambdaServer(behavior: BadBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result = Lambda.run(handler: CodableEchoHandler())
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testClosureSuccess() {
        let server = MockLambdaServer(behavior: GoodBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 1 ... 10)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration) { (_, payload: Request, callback) in
            callback(.success(Response(requestId: payload.requestId)))
        }
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() {
        let server = MockLambdaServer(behavior: BadBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result: LambdaLifecycleResult = Lambda.run { (_, payload: Request, callback) in
            callback(.success(Response(requestId: payload.requestId)))
        }
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

// TODO: taking advantage of the fact we know the serialization is json
private struct GoodBehavior: LambdaServerBehavior {
    let requestId = UUID().uuidString

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

    func processResponse(requestId: String, response: String) -> ProcessResponseResult {
        guard let data = response.data(using: .utf8) else {
            XCTFail("decoding error")
            return .failure(.internalServerError)
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            XCTFail("decoding error")
            return .failure(.internalServerError)
        }
        XCTAssertEqual(self.requestId, response.requestId, "expecting requestId to match")
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

private struct CodableEchoHandler: LambdaCodableHandler {
    func handle(context: Lambda.Context, payload: Request, callback: @escaping LambdaCodableCallback<Response>) {
        callback(.success(Response(requestId: payload.requestId)))
    }
}
