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
    func testGetWorkServerInternalError() throws {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .failure(.internalServerError)
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.internalServerError)
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? LambdaRuntimeClientError, LambdaRuntimeClientError.badStatusCode(.internalServerError))
        }
    }

    func testGetWorkServerNoBodyError() throws {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success(("1", ""))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.internalServerError)
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? LambdaRuntimeClientError, LambdaRuntimeClientError.noBody)
        }
    }

    func testGetWorkServerMissingHeaderRequestIDError() throws {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                // no request id -> no context
                return .success(("", "hello"))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.internalServerError)
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? LambdaRuntimeClientError, LambdaRuntimeClientError.invocationMissingHeader(AmazonHeaders.requestID))
        }
    }

    func testProcessResponseInternalServerError() throws {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success((requestId: "1", payload: "payload"))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                return .failure(.internalServerError)
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: EchoHandler())) { error in
            XCTAssertEqual(error as? LambdaRuntimeClientError, LambdaRuntimeClientError.badStatusCode(.internalServerError))
        }
    }

    func testProcessErrorInternalServerError() throws {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success((requestId: "1", payload: "payload"))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTFail("should not report results")
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
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: FailedHandler("boom"))) { error in
            XCTAssertEqual(error as? LambdaRuntimeClientError, LambdaRuntimeClientError.badStatusCode(.internalServerError))
        }
    }

    func testProcessInitErrorInternalServerError() throws {
        struct Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                XCTFail("should not get work")
                return .failure(.internalServerError)
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
                return .failure(.internalServerError)
            }
        }
        XCTAssertThrowsError(try runLambda(behavior: Behavior(), handler: FailedInitializerHandler("boom"))) { error in
            XCTAssertEqual(error as? FailedInitializerHandler.Error, FailedInitializerHandler.Error(description: "boom"))
        }
    }
}
