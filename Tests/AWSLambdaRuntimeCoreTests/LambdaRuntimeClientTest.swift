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
import NIO
import NIOFoundationCompat
import NIOHTTP1
import NIOTestUtils
import XCTest

class LambdaRuntimeClientTest: XCTestCase {
    func testSuccess() {
        let behavior = Behavior()
        XCTAssertNoThrow(try runLambda(behavior: behavior, handler: EchoHandler()))
        XCTAssertEqual(behavior.state, 6)
    }

    func testFailure() {
        let behavior = Behavior()
        XCTAssertNoThrow(try runLambda(behavior: behavior, handler: FailedHandler("boom")))
        XCTAssertEqual(behavior.state, 10)
    }

    func testBootstrapFailure() {
        let behavior = Behavior()
        XCTAssertThrowsError(try runLambda(behavior: behavior, factory: { $0.eventLoop.makeFailedFuture(TestError("boom")) })) { error in
            XCTAssertEqual(error as? TestError, TestError("boom"))
        }
        XCTAssertEqual(behavior.state, 1)
    }

    func testGetInvocationServerInternalError() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                .failure(.internalServerError)
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should not report results")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .badStatusCode(.internalServerError))
        }
    }

    func testGetInvocationServerNoBodyError() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                .success(("1", ""))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should not report results")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .noBody)
        }
    }

    func testGetInvocationServerMissingHeaderRequestIDError() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                // no request id -> no context
                .success(("", "hello"))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should not report results")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .invocationMissingHeader(AmazonHeaders.requestID))
        }
    }

    func testProcessResponseInternalServerError() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                .success((requestId: "1", event: "event"))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .badStatusCode(.internalServerError))
        }
    }

    func testProcessErrorInternalServerError() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                .success((requestId: "1", event: "event"))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should not report results")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: FailedHandler("boom"))) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .badStatusCode(.internalServerError))
        }
    }

    func testProcessInitErrorOnBootstrapFailure() {
        struct Behavior: LambdaServerBehavior {
            func getInvocation() -> GetInvocationResult {
                XCTFail("should not get invocation")
                return .failure(.internalServerError)
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should not report results")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), factory: { $0.eventLoop.makeFailedFuture(TestError("boom")) })) { error in
            XCTAssertEqual(error as? TestError, TestError("boom"))
        }
    }

    func testErrorResponseToJSON() {
        // we want to check if quotes and back slashes are correctly escaped
        let windowsError = ErrorResponse(
            errorType: "error",
            errorMessage: #"underlyingError: "An error with a windows path C:\Windows\""#
        )
        let windowsBytes = windowsError.toJSONBytes()
        XCTAssertEqual(#"{"errorType":"error","errorMessage":"underlyingError: \"An error with a windows path C:\\Windows\\\""}"#, String(decoding: windowsBytes, as: Unicode.UTF8.self))

        // we want to check if unicode sequences work
        let emojiError = ErrorResponse(
            errorType: "error",
            errorMessage: #"🥑👨‍👩‍👧‍👧👩‍👩‍👧‍👧👨‍👨‍👧"#
        )
        let emojiBytes = emojiError.toJSONBytes()
        XCTAssertEqual(#"{"errorType":"error","errorMessage":"🥑👨‍👩‍👧‍👧👩‍👩‍👧‍👧👨‍👨‍👧"}"#, String(decoding: emojiBytes, as: Unicode.UTF8.self))
    }

    func testInitializationErrorReport() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let server = NIOHTTP1TestServer(group: eventLoopGroup)
        defer { XCTAssertNoThrow(try server.stop()) }

        let logger = Logger(label: "TestLogger")
        let client = Lambda.RuntimeClient(eventLoop: eventLoopGroup.next(), configuration: .init(address: "127.0.0.1:\(server.serverPort)"))
        let result = client.reportInitializationError(logger: logger, error: TestError("boom"))

        var inboundHeader: HTTPServerRequestPart?
        XCTAssertNoThrow(inboundHeader = try server.readInbound())
        guard case .head(let head) = try? XCTUnwrap(inboundHeader) else { XCTFail("Expected to get a head first"); return }
        XCTAssertEqual(head.headers["lambda-runtime-function-error-type"], ["Unhandled"])
        XCTAssertEqual(head.headers["user-agent"], ["Swift-Lambda/Unknown"])

        var inboundBody: HTTPServerRequestPart?
        XCTAssertNoThrow(inboundBody = try server.readInbound())
        guard case .body(let body) = try? XCTUnwrap(inboundBody) else { XCTFail("Expected body after head"); return }
        XCTAssertEqual(try JSONDecoder().decode(ErrorResponse.self, from: body).errorMessage, "boom")

        XCTAssertEqual(try server.readInbound(), .end(nil))

        XCTAssertNoThrow(try server.writeOutbound(.head(.init(version: .init(major: 1, minor: 1), status: .accepted))))
        XCTAssertNoThrow(try server.writeOutbound(.end(nil)))
        XCTAssertNoThrow(try result.wait())
    }

    func testInvocationErrorReport() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let server = NIOHTTP1TestServer(group: eventLoopGroup)
        defer { XCTAssertNoThrow(try server.stop()) }

        let logger = Logger(label: "TestLogger")
        let client = Lambda.RuntimeClient(eventLoop: eventLoopGroup.next(), configuration: .init(address: "127.0.0.1:\(server.serverPort)"))

        let header = HTTPHeaders([
            (AmazonHeaders.requestID, "test"),
            (AmazonHeaders.deadline, String(Date(timeIntervalSinceNow: 60).millisSinceEpoch)),
            (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime"),
            (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
        ])
        var inv: Lambda.Invocation?
        XCTAssertNoThrow(inv = try Lambda.Invocation(headers: header))
        guard let invocation = inv else { return }

        let result = client.reportResults(logger: logger, invocation: invocation, result: Result.failure(TestError("boom")))

        var inboundHeader: HTTPServerRequestPart?
        XCTAssertNoThrow(inboundHeader = try server.readInbound())
        guard case .head(let head) = try? XCTUnwrap(inboundHeader) else { XCTFail("Expected to get a head first"); return }
        XCTAssertEqual(head.headers["lambda-runtime-function-error-type"], ["Unhandled"])
        XCTAssertEqual(head.headers["user-agent"], ["Swift-Lambda/Unknown"])

        var inboundBody: HTTPServerRequestPart?
        XCTAssertNoThrow(inboundBody = try server.readInbound())
        guard case .body(let body) = try? XCTUnwrap(inboundBody) else { XCTFail("Expected body after head"); return }
        XCTAssertEqual(try JSONDecoder().decode(ErrorResponse.self, from: body).errorMessage, "boom")

        XCTAssertEqual(try server.readInbound(), .end(nil))

        XCTAssertNoThrow(try server.writeOutbound(.head(.init(version: .init(major: 1, minor: 1), status: .accepted))))
        XCTAssertNoThrow(try server.writeOutbound(.end(nil)))
        XCTAssertNoThrow(try result.wait())
    }

    func testInvocationSuccessResponse() {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let server = NIOHTTP1TestServer(group: eventLoopGroup)
        defer { XCTAssertNoThrow(try server.stop()) }

        let logger = Logger(label: "TestLogger")
        let client = Lambda.RuntimeClient(eventLoop: eventLoopGroup.next(), configuration: .init(address: "127.0.0.1:\(server.serverPort)"))

        let header = HTTPHeaders([
            (AmazonHeaders.requestID, "test"),
            (AmazonHeaders.deadline, String(Date(timeIntervalSinceNow: 60).millisSinceEpoch)),
            (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime"),
            (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
        ])
        var inv: Lambda.Invocation?
        XCTAssertNoThrow(inv = try Lambda.Invocation(headers: header))
        guard let invocation = inv else { return }

        let result = client.reportResults(logger: logger, invocation: invocation, result: Result.success(nil))

        var inboundHeader: HTTPServerRequestPart?
        XCTAssertNoThrow(inboundHeader = try server.readInbound())
        guard case .head(let head) = try? XCTUnwrap(inboundHeader) else { XCTFail("Expected to get a head first"); return }
        XCTAssertFalse(head.headers.contains(name: "lambda-runtime-function-error-type"))
        XCTAssertEqual(head.headers["user-agent"], ["Swift-Lambda/Unknown"])

        XCTAssertEqual(try server.readInbound(), .end(nil))

        XCTAssertNoThrow(try server.writeOutbound(.head(.init(version: .init(major: 1, minor: 1), status: .accepted))))
        XCTAssertNoThrow(try server.writeOutbound(.end(nil)))
        XCTAssertNoThrow(try result.wait())
    }

    class Behavior: LambdaServerBehavior {
        var state = 0

        func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
            self.state += 1
            return .success(())
        }

        func getInvocation() -> GetInvocationResult {
            self.state += 2
            return .success(("1", "hello"))
        }

        func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
            self.state += 4
            return .success(())
        }

        func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
            self.state += 8
            return .success(())
        }
    }
}
