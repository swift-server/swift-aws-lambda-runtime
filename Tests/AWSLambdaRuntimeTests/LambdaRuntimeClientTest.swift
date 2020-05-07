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

@testable import AWSLambdaRuntime
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
        XCTAssertThrowsError(try runLambda(behavior: behavior, factory: { $0.makeFailedFuture(TestError("boom")) })) { error in
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
                .success((requestId: "1", payload: "payload"))
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
                .success((requestId: "1", payload: "payload"))
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), factory: { $0.makeFailedFuture(TestError("boom")) })) { error in
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
