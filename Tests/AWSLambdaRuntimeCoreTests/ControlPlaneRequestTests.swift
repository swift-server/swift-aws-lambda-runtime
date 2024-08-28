//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOHTTP1
import XCTest

@testable import AWSLambdaRuntimeCore

class InvocationTest: XCTestCase {
    func testInvocationTraceID() throws {
        let headers = HTTPHeaders([
            (AmazonHeaders.requestID, "test"),
            (AmazonHeaders.deadline, String(Date(timeIntervalSinceNow: 60).millisSinceEpoch)),
            (AmazonHeaders.invokedFunctionARN, "arn:aws:lambda:us-east-1:123456789012:function:custom-runtime"),
        ])

        var invocation: InvocationMetadata?

        XCTAssertNoThrow(invocation = try InvocationMetadata(headers: headers))
        XCTAssertNotNil(invocation)

        guard !invocation!.traceID.isEmpty else {
            XCTFail("Invocation traceID is empty")
            return
        }
    }
}
