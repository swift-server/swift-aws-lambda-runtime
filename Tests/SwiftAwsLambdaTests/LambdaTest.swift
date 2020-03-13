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

import Logging
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
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
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

    func testBootstrapOnce() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = String
            typealias Out = String

            var initialized = false

            init(eventLoop: EventLoop) {
                XCTAssertFalse(self.initialized)
                self.initialized = true
            }

            func handle(context: Lambda.Context, payload: String, callback: (Result<String, Error>) -> Void) {
                callback(.success(payload))
            }
        }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, factory: Handler.init)
        assertLambdaLifecycleResult(result, shoudHaveRun: maxTimes)
    }

    func testBootstrapFailure() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result = Lambda.run(factory: { $0.makeFailedFuture(TestError("kaboom")) })
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }

    func testBootstrapFailure2() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Handler: LambdaHandler {
            typealias In = String
            typealias Out = Void

            init(eventLoop: EventLoop) throws {
                throw TestError("kaboom")
            }

            func handle(context: Lambda.Context, payload: String, callback: (Result<Void, Error>) -> Void) {
                callback(.failure(TestError("should not be called")))
            }
        }

        let result = Lambda.run(factory: Handler.init)
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }

    func testBootstrapFailureAndReportErrorFailure() {
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
                .failure(.internalServerError)
            }
        }

        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result = Lambda.run(factory: { $0.makeFailedFuture(TestError("kaboom")) })
        assertLambdaLifecycleResult(result, shouldFailWithError: TestError("kaboom"))
    }

    func testStartStop() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let signal = Signal.ALRM
        let maxTimes = 1000
        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: maxTimes, stopSignal: signal))
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let future = Lambda.runAsync(eventLoopGroup: eventLoopGroup, configuration: configuration, factory: { $0.makeSucceededFuture(EchoHandler()) })
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

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1),
                                                 runtimeEngine: .init(requestTimeout: .milliseconds(timeout)))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shouldFailWithError: Lambda.RuntimeError.upstreamError("timeout"))
    }

    func testDisconnect() {
        let server = MockLambdaServer(behavior: Behavior(requestId: "disconnect"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = Lambda.Configuration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(configuration: configuration, handler: EchoHandler())
        assertLambdaLifecycleResult(result, shouldFailWithError: Lambda.RuntimeError.upstreamError("connectionResetByPeer"))
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

    func testServerFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                .failure(.internalServerError)
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }

        let result = Lambda.run(handler: EchoHandler())
        assertLambdaLifecycleResult(result, shouldFailWithError: Lambda.RuntimeError.badStatusCode(.internalServerError))
    }

    func testDeadline() {
        let delta = Int.random(in: 1 ... 600)

        let milli1 = Date(timeIntervalSinceNow: Double(delta)).millisSinceEpoch
        let milli2 = (DispatchWallTime.now() + .seconds(delta)).millisSinceEpoch
        XCTAssertEqual(Double(milli1), Double(milli2), accuracy: 2.0)

        let now1 = DispatchWallTime.now()
        let now2 = DispatchWallTime(millisSinceEpoch: Date().millisSinceEpoch)
        XCTAssertEqual(Double(now2.rawValue), Double(now1.rawValue), accuracy: 2_000_000.0)

        let future1 = DispatchWallTime.now() + .seconds(delta)
        let future2 = DispatchWallTime(millisSinceEpoch: Date(timeIntervalSinceNow: Double(delta)).millisSinceEpoch)
        XCTAssertEqual(Double(future1.rawValue), Double(future2.rawValue), accuracy: 2_000_000.0)

        let past1 = DispatchWallTime.now() - .seconds(delta)
        let past2 = DispatchWallTime(millisSinceEpoch: Date(timeIntervalSinceNow: Double(-delta)).millisSinceEpoch)
        XCTAssertEqual(Double(past1.rawValue), Double(past2.rawValue), accuracy: 2_000_000.0)

        let context = Lambda.Context(requestId: UUID().uuidString,
                                     traceId: UUID().uuidString,
                                     invokedFunctionArn: UUID().uuidString,
                                     deadline: .now() + .seconds(1),
                                     cognitoIdentity: nil,
                                     clientContext: nil,
                                     logger: Logger(label: "test"),
                                     eventLoop: MultiThreadedEventLoopGroup(numberOfThreads: 1).next())
        XCTAssertGreaterThan(context.deadline, .now())

        let expiredContext = Lambda.Context(requestId: context.requestId,
                                            traceId: context.traceId,
                                            invokedFunctionArn: context.invokedFunctionArn,
                                            deadline: .now() - .seconds(1),
                                            cognitoIdentity: context.cognitoIdentity,
                                            clientContext: context.clientContext,
                                            logger: context.logger,
                                            eventLoop: context.eventLoop)
        XCTAssertLessThan(expiredContext.deadline, .now())
    }

    func testGetRemainingTime() {
        let context = Lambda.Context(requestId: UUID().uuidString,
                                     traceId: UUID().uuidString,
                                     invokedFunctionArn: UUID().uuidString,
                                     deadline: .now() + .seconds(1),
                                     cognitoIdentity: nil,
                                     clientContext: nil,
                                     logger: Logger(label: "test"),
                                     eventLoop: MultiThreadedEventLoopGroup(numberOfThreads: 1).next())
        XCTAssertLessThanOrEqual(context.getRemainingTime(), .seconds(1))
        XCTAssertGreaterThan(context.getRemainingTime(), .milliseconds(800))
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

struct FailedBootstrapBehavior: LambdaServerBehavior {
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
        .success(())
    }
}
