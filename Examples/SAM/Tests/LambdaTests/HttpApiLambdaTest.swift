// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime
import AWSLambdaTesting
import XCTest
@testable import HttpApiLambda

class HttpApiLambdaTests: LambdaTest {

    func testHttpAPiLambda() async throws {
            
            // given 
            let eventData = try self.loadTestData(file: .apiGatewayV2)
            let event = try JSONDecoder().decode(APIGatewayV2Request.self, from: eventData)

            do {
                // when 
                let result = try await Lambda.test(HttpApiLambda.self, with: event)

                // then   
                XCTAssertEqual(result.statusCode.code, 200)
                XCTAssertNotNil(result.headers)
                if let headers = result.headers {
                    XCTAssertNotNil(headers["content-type"])
                    if let contentType = headers["content-type"] {
                        XCTAssertTrue(contentType == "application/json")
                    }
                }
            } catch {
                XCTFail("Lambda invocation should not throw error : \(error)")
            }
        }
}
