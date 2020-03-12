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

    func testGetWorkServerInternalError() {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
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
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .badStatusCode(.internalServerError))
        }
    }

    func testGetWorkServerNoBodyError() {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success(("1", ""))
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

    func testGetWorkServerMissingHeaderRequestIDError() {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                // no request id -> no context
                return .success(("", "hello"))
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
            func getWork() -> GetWorkResult {
                return .success((requestId: "1", payload: "payload"))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
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

    func testProcessErrorInternalServerError() {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success((requestId: "1", payload: "payload"))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should not report results")
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: FailedHandler("boom"))) { error in
            XCTAssertEqual(error as? Lambda.RuntimeError, .badStatusCode(.internalServerError))
        }
    }

    func testProcessInitErrorOnBootstrapFailure() {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                XCTFail("should not get work")
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
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), factory: { $0.makeFailedFuture(TestError("boom")) })) { error in
            XCTAssertEqual(error as? TestError, TestError("boom"))
        }
    }

    class Behavior: LambdaServerBehavior {
        var state = 0

        func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
            self.state += 1
            return .success(())
        }

        func getWork() -> GetWorkResult {
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
