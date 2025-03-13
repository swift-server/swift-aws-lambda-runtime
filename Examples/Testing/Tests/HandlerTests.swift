//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime
import Logging
import Testing

@testable import APIGatewayLambda  // to access the business code
@testable import AWSLambdaRuntime  // to access the LambdaContext

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("Handler Tests")
public struct HandlerTest {

    @Test("Invoke handler")
    public func invokeHandler() async throws {

        // read event.json file
        let testBundle = Bundle.module
        guard let eventURL = testBundle.url(forResource: "event", withExtension: "json") else {
            Issue.record("event.json not found in test bundle")
            return
        }
        let eventData = try Data(contentsOf: eventURL)

        // decode the event
        let apiGatewayRequest = try JSONDecoder().decode(APIGatewayV2Request.self, from: eventData)

        // create a mock LambdaContext
        let lambdaContext = LambdaContext.__forTestsOnly(
            requestID: UUID().uuidString,
            traceID: UUID().uuidString,
            invokedFunctionARN: "arn:",
            timeout: .milliseconds(6000),
            logger: Logger(label: "fakeContext")
        )

        // call the handler with the event and context
        let response = try await MyHandler().handler(event: apiGatewayRequest, context: lambdaContext)

        // assert the response
        #expect(response.statusCode == .ok)
        #expect(response.body == "Hello world of swift lambda!")
    }
}
