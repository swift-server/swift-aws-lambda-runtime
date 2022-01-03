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

@testable import AWSLambdaRuntimeCore
import NIOCore
import NIOTestUtils
import XCTest

final class ControlPlaneResponseDecoderTests: XCTestCase {
    func testNextAndAcceptedResponse() {
        let nextResponse = ByteBuffer(string: """
            HTTP/1.1 200 OK\r\n\
            Content-Type: application/json\r\n\
            Lambda-Runtime-Aws-Request-Id: 9028dc49-a01b-4b44-8ffe-4912e9dabbbd\r\n\
            Lambda-Runtime-Deadline-Ms: 1638392696671\r\n\
            Lambda-Runtime-Invoked-Function-Arn: arn:aws:lambda:eu-central-1:079477498937:function:lambda-log-http-HelloWorldLambda-NiDlzMFXtF3x\r\n\
            Lambda-Runtime-Trace-Id: Root=1-61a7e375-40b3edf95b388fe75d1fa416;Parent=348bb48e251c1254;Sampled=0\r\n\
            Date: Wed, 01 Dec 2021 21:04:53 GMT\r\n\
            Content-Length: 49\r\n\
            \r\n\
            {"name":"Fabian","key2":"value2","key3":"value3"}
            """
        )
        let invocation = Invocation(
            requestID: "9028dc49-a01b-4b44-8ffe-4912e9dabbbd",
            deadlineInMillisSinceEpoch: 1_638_392_696_671,
            invokedFunctionARN: "arn:aws:lambda:eu-central-1:079477498937:function:lambda-log-http-HelloWorldLambda-NiDlzMFXtF3x",
            traceID: "Root=1-61a7e375-40b3edf95b388fe75d1fa416;Parent=348bb48e251c1254;Sampled=0",
            clientContext: nil,
            cognitoIdentity: nil
        )
        let next: ControlPlaneResponse = .next(invocation, ByteBuffer(string: #"{"name":"Fabian","key2":"value2","key3":"value3"}"#))

        let acceptedResponse = ByteBuffer(string: """
            HTTP/1.1 202 Accepted\r\n\
            Content-Type: application/json\r\n\
            Date: Sun, 05 Dec 2021 11:53:40 GMT\r\n\
            Content-Length: 16\r\n\
            \r\n\
            {"status":"OK"}\n
            """
        )

        let pairs: [(ByteBuffer, [ControlPlaneResponse])] = [
            (nextResponse, [next]),
            (acceptedResponse, [.accepted]),
            (nextResponse + acceptedResponse, [next, .accepted]),
        ]

        XCTAssertNoThrow(try ByteToMessageDecoderVerifier.verifyDecoder(
            inputOutputPairs: pairs,
            decoderFactory: { ControlPlaneResponseDecoder() }
        ))
    }
}

extension ByteBuffer {
    static func + (lhs: Self, rhs: Self) -> ByteBuffer {
        var new = lhs
        var rhs = rhs
        new.writeBuffer(&rhs)
        return new
    }
}
