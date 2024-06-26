//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaRuntimeCore
import Logging
import NIOCore
import NIOPosix
import XCTest

class LambdaTest: XCTestCase {
    func testSuccess() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldHaveRun: maxTimes)
    }

    func testFailure() {
        let server = MockLambdaServer(behavior: Behavior(result: .failure(RuntimeError())))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = Int.random(in: 10 ... 20)
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handlerType: RuntimeErrorHandler.self)
        assertLambdaRuntimeResult(result, shouldHaveRun: maxTimes)
    }

    func testBootstrapFailure() {
        let server = MockLambdaServer(behavior: FailedBootstrapBehavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let result = Lambda.run(configuration: .init(), handlerType: StartupErrorHandler.self)
        assertLambdaRuntimeResult(result, shouldFailWithError: StartupError())
    }

    func testBootstrapFailureAndReportErrorFailure() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                XCTFail("should not get invocation")
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

        let result = Lambda.run(configuration: .init(), handlerType: StartupErrorHandler.self)
        assertLambdaRuntimeResult(result, shouldFailWithError: StartupError())
    }

    func testStartStopInDebugMode() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let signal = Signal.ALRM
        let maxTimes = 1000
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes, stopSignal: signal))

        DispatchQueue(label: "test").async {
            // we need to schedule the signal before we start the long running `Lambda.run`, since
            // `Lambda.run` will block the main thread.
            usleep(100_000)
            kill(getpid(), signal.rawValue)
        }
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)

        switch result {
        case .success(let invocationCount):
            XCTAssertGreaterThan(invocationCount, 0, "should have stopped before any request made")
            XCTAssertLessThan(invocationCount, maxTimes, "should have stopped before \(maxTimes)")
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeout() {
        let timeout: Int64 = 100
        let server = MockLambdaServer(behavior: Behavior(requestId: "timeout", event: "\(timeout * 2)"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: 1),
                                                runtimeEngine: .init(requestTimeout: .milliseconds(timeout)))
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldFailWithError: LambdaRuntimeError.upstreamError("timeout"))
    }

    func testDisconnect() {
        let server = MockLambdaServer(behavior: Behavior(requestId: "disconnect"))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldFailWithError: LambdaRuntimeError.upstreamError("connectionResetByPeer"))
    }

    func testBigEvent() {
        let event = String(repeating: "*", count: 104_448)
        let server = MockLambdaServer(behavior: Behavior(event: event, result: .success(event)))
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: 1))
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldHaveRun: 1)
    }

    func testKeepAliveServer() {
        let server = MockLambdaServer(behavior: Behavior(), keepAlive: true)
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = 10
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldHaveRun: maxTimes)
    }

    func testNoKeepAliveServer() {
        let server = MockLambdaServer(behavior: Behavior(), keepAlive: false)
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let maxTimes = 10
        let configuration = LambdaConfiguration(lifecycle: .init(maxTimes: maxTimes))
        let result = Lambda.run(configuration: configuration, handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldHaveRun: maxTimes)
    }

    func testServerFailure() {
        let server = MockLambdaServer(behavior: Behavior())
        XCTAssertNoThrow(try server.start().wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
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

        let result = Lambda.run(configuration: .init(), handlerType: EchoHandler.self)
        assertLambdaRuntimeResult(result, shouldFailWithError: LambdaRuntimeError.badStatusCode(.internalServerError))
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

        let context = LambdaContext(
            requestID: UUID().uuidString,
            traceID: UUID().uuidString,
            invokedFunctionARN: UUID().uuidString,
            deadline: .now() + .seconds(1),
            cognitoIdentity: nil,
            clientContext: nil,
            logger: Logger(label: "test"),
            eventLoop: MultiThreadedEventLoopGroup(numberOfThreads: 1).next(),
            allocator: ByteBufferAllocator()
        )
        XCTAssertGreaterThan(context.deadline, .now())

        let expiredContext = LambdaContext(
            requestID: context.requestID,
            traceID: context.traceID,
            invokedFunctionARN: context.invokedFunctionARN,
            deadline: .now() - .seconds(1),
            cognitoIdentity: context.cognitoIdentity,
            clientContext: context.clientContext,
            logger: context.logger,
            eventLoop: context.eventLoop,
            allocator: context.allocator
        )
        XCTAssertLessThan(expiredContext.deadline, .now())
    }

    func testGetRemainingTime() {
        let context = LambdaContext(
            requestID: UUID().uuidString,
            traceID: UUID().uuidString,
            invokedFunctionARN: UUID().uuidString,
            deadline: .now() + .seconds(1),
            cognitoIdentity: nil,
            clientContext: nil,
            logger: Logger(label: "test"),
            eventLoop: MultiThreadedEventLoopGroup(numberOfThreads: 1).next(),
            allocator: ByteBufferAllocator()
        )
        XCTAssertLessThanOrEqual(context.getRemainingTime(), .seconds(1))
        XCTAssertGreaterThan(context.getRemainingTime(), .milliseconds(800))
    }

    #if compiler(>=5.6)
    func testSendable() async throws {
        struct Handler: EventLoopLambdaHandler {
            static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Handler> {
                context.eventLoop.makeSucceededFuture(Handler())
            }

            func handle(_ event: String, context: LambdaContext) -> EventLoopFuture<String> {
                context.eventLoop.makeSucceededFuture("hello")
            }
        }

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let server = try await MockLambdaServer(behavior: Behavior()).start().get()
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let logger = Logger(label: "TestLogger")
        let configuration = LambdaConfiguration(runtimeEngine: .init(requestTimeout: .milliseconds(100)))

        let handler1 = Handler()
        let task = Task.detached {
            print(configuration.description)
            logger.info("hello")
            let runner = LambdaRunner(eventLoop: eventLoopGroup.next(), configuration: configuration, allocator: ByteBufferAllocator())

            try await runner.run(
                handler: CodableEventLoopLambdaHandler(
                    handler: handler1,
                    allocator: ByteBufferAllocator()
                ),
                logger: logger
            ).get()

            try await runner.initialize(handlerType: CodableEventLoopLambdaHandler<Handler>.self, logger: logger, terminator: LambdaTerminator()).flatMap { handler2 in
                runner.run(handler: handler2, logger: logger)
            }.get()
        }

        try await task.value
    }
    #endif
}

private struct Behavior: LambdaServerBehavior {
    let requestId: String
    let event: String
    let result: Result<String?, RuntimeError>

    init(requestId: String = UUID().uuidString, event: String = "hello", result: Result<String?, RuntimeError> = .success("hello")) {
        self.requestId = requestId
        self.event = event
        self.result = result
    }

    func getInvocation() -> GetInvocationResult {
        .success((requestId: self.requestId, event: self.event))
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
            XCTAssertEqual(String(describing: expected), error.errorMessage, "expecting error to match")
            return .success(())
        }
    }

    func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
        XCTFail("should not report init error")
        return .failure(.internalServerError)
    }
}

struct FailedBootstrapBehavior: LambdaServerBehavior {
    func getInvocation() -> GetInvocationResult {
        XCTFail("should not get invocation")
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
