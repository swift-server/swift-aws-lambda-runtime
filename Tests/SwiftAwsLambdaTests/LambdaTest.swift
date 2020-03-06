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
    func testSuccess() {
        let server = MockLambdaServer(behavior: GoodBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let handler = EchoHandler()
        let result = Lambda.run(handler: handler, configuration: configuration)
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
        XCTAssertEqual(handler.initializeCalls, 1)
    }

    func testFailure() {
        let server = MockLambdaServer(behavior: BadBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result = Lambda.run(handler: EchoHandler())
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testInitFailure() {
        let server = MockLambdaServer(behavior: GoodBehaviourWhenInitFails())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let handler = FailedInitializerHandler("kaboom")
        let result = Lambda.run(handler: handler)
        assertLambdaLifecycleResult(result: result, shouldFailWithError: FailedInitializerHandler.Error(description: "kaboom"))
    }

    func testInitFailureAndReportErrorFailure() {
        let server = MockLambdaServer(behavior: BadBehaviourWhenInitFails())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let handler = FailedInitializerHandler("kaboom")
        let result = Lambda.run(handler: handler)
        assertLambdaLifecycleResult(result: result, shouldFailWithError: FailedInitializerHandler.Error(description: "kaboom"))
    }

    func testClosureSuccess() {
        let server = MockLambdaServer(behavior: GoodBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration) { (_, payload: [UInt8], callback: LambdaCallback) in
            callback(.success(payload))
        }
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testClosureFailure() {
        let server = MockLambdaServer(behavior: BadBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result: LambdaLifecycleResult = Lambda.run { (_, payload: [UInt8], callback: LambdaCallback) in
            callback(.success(payload))
        }
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
        let maxTimes = 1000
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes, stopSignal: signal))
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let future = Lambda.runAsync(eventLoopGroup: eventLoopGroup, handler: MyHandler(), configuration: configuration)
        DispatchQueue(label: "test").async {
            usleep(100_000)
            kill(getpid(), signal.rawValue)
        }
        let result = try future.wait()
        XCTAssertGreaterThan(result, 0, "should have stopped before any request made")
        XCTAssertLessThan(result, maxTimes, "should have stopped before \(maxTimes)")
        try server.stop().wait()
        try eventLoopGroup.syncShutdownGracefully()
    }

    func testTimeout() {
        let timeout: Int64 = 100
        let server = MockLambdaServer(behavior: GoodBehavior(requestId: "timeout", payload: "\(timeout * 2)"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1),
                                                 runtimeEngine: .init(requestTimeout: .milliseconds(timeout)))
        let result = Lambda.run(handler: EchoHandler(), configuration: configuration)
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.upstreamError("timeout"))
    }

    func testDisconnect() {
        let server = MockLambdaServer(behavior: GoodBehavior(requestId: "disconnect"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(handler: EchoHandler(), configuration: configuration)
        assertLambdaLifecycleResult(result: result, shouldFailWithError: LambdaRuntimeClientError.upstreamError("connectionResetByPeer"))
    }

    func testBigPayload() {
        let payload = String(repeating: "*", count: 104_448)
        let server = MockLambdaServer(behavior: GoodBehavior(payload: payload))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(handler: EchoHandler(), configuration: configuration)
        assertLambdaLifecycleResult(result: result, shoudHaveRun: 1)
    }

    func testKeepAliveServer() {
        let server = MockLambdaServer(behavior: GoodBehavior(), keepAlive: true)
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = 10
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(handler: EchoHandler(), configuration: configuration)
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
    }

    func testNoKeepAliveServer() {
        let server = MockLambdaServer(behavior: GoodBehavior(), keepAlive: false)
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = 10
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(handler: EchoHandler(), configuration: configuration)
        assertLambdaLifecycleResult(result: result, shoudHaveRun: maxTimes)
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

private struct GoodBehavior: LambdaServerBehavior {
    let requestId: String
    let payload: String

    init(requestId: String = UUID().uuidString, payload: String = UUID().uuidString) {
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
        XCTFail("should not report init error")
        return .failure(.internalServerError)
    }
}

private struct GoodBehaviourWhenInitFails: LambdaServerBehavior {
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

private struct BadBehaviourWhenInitFails: LambdaServerBehavior {
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
