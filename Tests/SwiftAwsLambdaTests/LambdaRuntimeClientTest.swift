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
        class Behavior: LambdaServerBehavior {
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
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler())
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testGetWorkServerNoBodyError() throws {
        class Behavior: LambdaServerBehavior {
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
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler())
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.noBody)
    }

    func testGetWorkServerNoContextError() throws {
        class Behavior: LambdaServerBehavior {
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
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler())
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.noContext)
    }

    func testProcessResponseInternalServerError() throws {
        class Behavior: LambdaServerBehavior {
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
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler())
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }

    func testProcessErrorInternalServerError() throws {
        class Behavior: LambdaServerBehavior {
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
        }
        let result = try runLambda(behavior: Behavior(), handler: FailedHandler("boom"))
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode(.internalServerError))
    }
}
