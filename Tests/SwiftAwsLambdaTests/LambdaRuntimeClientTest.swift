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
                return .failure(.InternalServerError)
            }

            func processResponse(requestId _: String, response _: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.InternalServerError)
            }

            func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.InternalServerError)
            }
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler()) // .wait()
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode)
    }

    func testGetWorkServerNoBodyError() throws {
        class Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success(requestId: "1", payload: "")
            }

            func processResponse(requestId _: String, response _: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.InternalServerError)
            }

            func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.InternalServerError)
            }
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler()) // .wait()
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.noBody)
    }

    func testGetWorkServerNoContextError() throws {
        class Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                // no request id -> no context
                return .success(requestId: "", payload: "hello")
            }

            func processResponse(requestId _: String, response _: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.InternalServerError)
            }

            func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.InternalServerError)
            }
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler()) // .wait()
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.noContext)
    }

    func testProcessResponseInternalServerError() throws {
        class Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success(requestId: "1", payload: "payload")
            }

            func processResponse(requestId _: String, response _: String) -> ProcessResponseResult {
                return .failure(.InternalServerError)
            }

            func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.InternalServerError)
            }
        }
        let result = try runLambda(behavior: Behavior(), handler: EchoHandler()) // .wait()
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode)
    }

    func testProcessErrorInternalServerError() throws {
        class Behavior: LambdaServerBehavior {
            func getWork() -> GetWorkResult {
                return .success(requestId: "1", payload: "payload")
            }

            func processResponse(requestId _: String, response _: String) -> ProcessResponseResult {
                XCTFail("should not report results")
                return .failure(.InternalServerError)
            }

            func processError(requestId _: String, error _: ErrorResponse) -> ProcessErrorResult {
                return .failure(.InternalServerError)
            }
        }
        let result = try runLambda(behavior: Behavior(), handler: FailedHandler("boom")) // .wait()
        assertRunLambdaResult(result: result, shouldFailWithError: LambdaRuntimeClientError.badStatusCode)
    }
}
