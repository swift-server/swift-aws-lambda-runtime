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
import XCTest

class LambdaRunnerTest: XCTestCase {
    func testSuccess() {
        struct Behavior: LambdaServerBehavior {
            let requestId = UUID().uuidString
            let event = "hello"
            func getInvocation() -> GetInvocationResult {
                .success((self.requestId, self.event))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
                XCTAssertEqual(self.event, response, "expecting response to match")
                return .success(())
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
        XCTAssertNoThrow(try runLambda(behavior: Behavior(), handler: EchoHandler()))
    }

    func testFailure() {
        struct Behavior: LambdaServerBehavior {
            static let error = "boom"
            let requestId = UUID().uuidString
            func getInvocation() -> GetInvocationResult {
                .success((requestId: self.requestId, event: "hello"))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                XCTFail("should report error")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
                XCTAssertEqual(Behavior.error, error.errorMessage, "expecting error to match")
                return .success(())
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertNoThrow(try runLambda(behavior: Behavior(), handler: FailedHandler(Behavior.error)))
    }
}
