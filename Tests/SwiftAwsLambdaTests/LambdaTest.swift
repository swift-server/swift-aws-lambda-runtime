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
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let handler = EchoHandler()
        let result = Lambda.run(configuration: configuration, handler: handler)
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
        XCTAssertEqual(handler.bootstrapped, 1)
    }

    func testFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(TestError("boom"))))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: FailedHandler("boom"))
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testServerFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .failure(.internalServerError)
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }

        let result = Lambda.run(handler: EchoHandler())
        assertLambdaLifecycleResult(result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testProviderFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                XCTFail("should not get work")
                return .failure(.internalServerError)
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
                return .success(())
            }
        }

        let result = Lambda.run(handler: FailedBootstrapHandler("kaboom"))
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }

    func testProviderFailureAndReportErrorFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                XCTFail("should not get work")
                return .failure(.internalServerError)
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
                return .failure(.internalServerError)
            }
        }

        let result = Lambda.run(provider: { _ in throw TestError("boom") })
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("boom"))
    }

    func testBootstrapFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                XCTFail("should not get work")
                return .failure(.internalServerError)
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
                return .success(())
            }
        }

        let result = Lambda.run(handler: FailedBootstrapHandler("kaboom"))
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }

    func testBootstrapFailureAndReportErrorFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                XCTFail("should not get work")
                return .failure(.internalServerError)
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
                return .failure(.internalServerError)
            }
        }

        let result = Lambda.run(handler: FailedBootstrapHandler("kaboom"))
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }

    func testStartStop() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            func handle(context: Lambda.Context, payload: [UInt8], callback: @escaping LambdaCallback) {
                callback(.success(payload))
            }
        }

        let signal = Signal.ALRM
        let maxTimes = 1000
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes, stopSignal: signal))
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let future = Lambda.runAsync(eventLoopGroup: eventLoopGroup, configuration: configuration, provider: { _ in Handler() })
        DispatchQueue(label: "test").async {
            usleep(100_000)
            kill(getpid(), signal.rawValue)
        }
        future.whenSuccess { result in
            XCTAssertGreaterThan(result, 0, "should have stopped before any request made")
            XCTAssertLessThan(result, maxTimes, "should have stopped before \(maxTimes)")
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testTimeout() {
        let timeout: Int64 = 100
        let server = MockLambdaServer(behavior: Behavior(requestId: "timeout", payload: "\(timeout * 2)"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1), runtimeEngine: .init(requestTimeout: .milliseconds(timeout)))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shouldFailWithError: LambdaRuntimeClientError.upstreamError("timeout"))
    }

    func testDisconnect() {
        let server = MockLambdaServer(behavior: Behavior(requestId: "disconnect"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shouldFailWithError: LambdaRuntimeClientError.upstreamError("connectionResetByPeer"))
    }

    func testBigPayload() {
        let payload = String(repeating: "*", count: 104_448)
        let server = MockLambdaServer(behavior: Behavior(payload: payload, result: .success(payload)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shoudHaveRun: 1)
    }

    func testKeepAliveServer() {
        let server = MockLambdaServer(behavior: Behavior(), keepAlive: true)
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = 10
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testNoKeepAliveServer() {
        let server = MockLambdaServer(behavior: Behavior(), keepAlive: false)
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = 10
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
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
