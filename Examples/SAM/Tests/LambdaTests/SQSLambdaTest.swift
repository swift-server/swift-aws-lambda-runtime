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
@testable import SQSLambda

class SQSLambdaTests: LambdaTest {

    func testSQSLambda() async throws {
            
            // given 
            let eventData = try self.loadTestData(file: .sqs)
            let event = try JSONDecoder().decode(SQSEvent.self, from: eventData)

            // when 
            do {
                try await Lambda.test(SQSLambda.self, with: event)
            } catch {
                XCTFail("Lambda invocation should not throw error : \(error)")
            }

            // then   
            // SQS Lambda returns Void

        }
}