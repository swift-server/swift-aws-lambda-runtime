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

class LambdaTest: XCTestCase {
    func testSuceess() throws {
        let maxTimes = Int.random(in: 10 ... 20)
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        let handler = EchoHandler()
        let result = Lambda.run(handler: handler, maxTimes: maxTimes)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
        XCTAssertEqual(handler.initializeCalls, 1)
    }

    func testFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehavior()).start().wait()
        let result = Lambda.run(handler: EchoHandler())
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testInitFailure() throws {
        let server = try MockLambdaServer(behavior: GoodBehaviourWhenInitFails()).start().wait()
        let handler = FailedInitializerHandler("kaboom")
        let result = Lambda.run(handler: handler)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: FailedInitializerHandler.Error(description: "kaboom"))
    }

    func testInitFailureAndReportErrorFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehaviourWhenInitFails()).start().wait()
        let handler = FailedInitializerHandler("kaboom")
        let result = Lambda.run(handler: handler)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: FailedInitializerHandler.Error(description: "kaboom"))
    }

    func testClosureSuccess() throws {
        let maxTimes = Int.random(in: 10 ... 20)
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        let result = Lambda.run(maxTimes: maxTimes) { (_, payload: [UInt8], callback: LambdaCallback) in
            callback(.success(payload))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() throws {
        let server = try MockLambdaServer(behavior: BadBehavior()).start().wait()
        let result: LambdaLifecycleResult = Lambda.run { (_, payload: [UInt8], callback: LambdaCallback) in
            callback(.success(payload))
        }
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testStartStop() throws {
        let server = try MockLambdaServer(behavior: GoodBehavior()).start().wait()
        struct MyHandler: LambdaHandler {
            func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
                callback(.success(payload))
            }
        }
        let signal = Signal.ALRM
        let max = 50
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let future = Lambda.runAsync(eventLoopGroup: eventLoopGroup, handler: MyHandler(), maxTimes: max, stopSignal: signal)
        DispatchQueue(label: "test").async {
            usleep(100_000)
            kill(getpid(), signal.rawValue)
        }
        let result = try future.wait()
        XCTAssertGreaterThan(result, 0, "should have stopped before any request made")
        XCTAssertLessThan(result, max, "should have stopped before \(max)")
        try server.stop().wait()
        try eventLoopGroup.syncShutdownGracefully()
    }

    func testTimeout() throws {
        let timeout = 100
        setenv(Consts.requestTimeoutEnvVariableName, "\(timeout)", 1)
        let server = try MockLambdaServer(behavior: GoodBehavior(requestId: "timeout", payload: "\(timeout * 2)")).start().wait()
        let result = Lambda.run(handler: EchoHandler(), maxTimes: 1)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.upstreamError("timeout"))
        unsetenv(Consts.requestTimeoutEnvVariableName)
    }

    func testDisconnect() throws {
        let server = try MockLambdaServer(behavior: GoodBehavior(requestId: "disconnect")).start().wait()
        let result = Lambda.run(handler: EchoHandler(), maxTimes: 1)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.upstreamError("connectionResetByPeer"))
    }

    func testBigPayload() throws {
        let payload = String(repeating: "*", count: 104_448)
        let server = try MockLambdaServer(behavior: GoodBehavior(payload: payload)).start().wait()
        let result = Lambda.run(handler: EchoHandler(), maxTimes: 1)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: 1)
    }

    func testKeepAliveServer() throws {
        let server = try MockLambdaServer(behavior: GoodBehavior(), keepAlive: true).start().wait()
        let result = Lambda.run(handler: EchoHandler(), maxTimes: 10)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: 10)
    }

    func testNoKeepAliveServer() throws {
        let server = try MockLambdaServer(behavior: GoodBehavior(), keepAlive: false).start().wait()
        let result = Lambda.run(handler: EchoHandler(), maxTimes: 10)
        try server.stop().wait()
        assertLambdaLifecycleResult(result: result, shoudHaveRun: 10)
    }
}

private func assertLambdaLifecycleResult(result: LambdaLifecycleResult, shoudHaveRun: Int = 0, shouldFailWithError: Error? = nil) {
    switch result {
    case .success(let count):
        if shouldFailWithError != nil {
            XCTFail("should fail with \(shouldFailWithError!)")
            break
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

private class GoodBehavior: LambdaServerBehavior {
    let requestId: String
    let payload: String

    init(requestId: String = NSUUID().uuidString, payload: String = NSUUID().uuidString) {
        self.requestId = requestId
        self.payload = payload
    }

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

private class BadBehavior: LambdaServerBehavior {
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
        XCTFail("should not report init error")
        return .failure(.internalServerError)
    }
}

private class GoodBehaviourWhenInitFails: LambdaServerBehavior {
    func getWork() -> GetWorkResult {
        XCTFail("should not get work")
        return .failure(.internalServerError)
    }

    func processResponse(requestId: String, response: String) -> ProcessResponseResult {
        XCTFail("should not report a response")
        return .failure(.internalServerError)
    }

    func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
        XCTFail("should not report an error")
        return .failure(.internalServerError)
    }

    func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
        return .success(())
    }
}

private class BadBehaviourWhenInitFails: LambdaServerBehavior {
    func getWork() -> GetWorkResult {
        XCTFail("should not get work")
        return .failure(.internalServerError)
    }

    func processResponse(requestId: String, response: String) -> ProcessResponseResult {
        XCTFail("should not report a response")
        return .failure(.internalServerError)
    }

    func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
        XCTFail("should not report an error")
        return .failure(.internalServerError)
    }

    func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
        return .failure(.internalServerError)
    }
}
