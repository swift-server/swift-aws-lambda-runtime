//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaEvents
import XCTest

class ALBTests: XCTestCase {
    static let exampleSingleValueHeadersEventBody = """
    {
      "requestContext":{
        "elb":{
          "targetGroupArn": "arn:aws:elasticloadbalancing:eu-central-1:079477498937:targetgroup/EinSternDerDeinenNamenTraegt/621febf5a44b2ce5"
        }
      },
      "httpMethod": "GET",
      "path": "/",
      "queryStringParameters": {},
      "headers":{
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "accept-encoding": "gzip, deflate",
        "accept-language": "en-us",
        "connection": "keep-alive",
        "host": "event-testl-1wa3wrvmroilb-358275751.eu-central-1.elb.amazonaws.com",
        "upgrade-insecure-requests": "1",
        "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.2 Safari/605.1.15",
        "x-amzn-trace-id": "Root=1-5e189143-ad18a2b0a7728cd0dac45e10",
        "x-forwarded-for": "90.187.8.137",
        "x-forwarded-port": "80",
        "x-forwarded-proto": "http"
      },
      "body":"",
      "isBase64Encoded":false
    }
    """

    func testRequestWithSingleValueHeadersEvent() {
        let data = ALBTests.exampleSingleValueHeadersEventBody.data(using: .utf8)!
        do {
            let decoder = JSONDecoder()

            let event = try decoder.decode(ALBTargetGroupRequest.self, from: data)

            XCTAssertEqual(event.httpMethod, .GET)
            XCTAssertEqual(event.body, "")
            XCTAssertEqual(event.isBase64Encoded, false)
            XCTAssertEqual(event.headers?.count, 11)
            XCTAssertEqual(event.path, "/")
            XCTAssertEqual(event.queryStringParameters, [:])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
