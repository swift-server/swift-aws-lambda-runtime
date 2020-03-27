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

class CloudwatchTests: XCTestCase {
    static let scheduledEventPayload = """
    {
      "id": "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c",
      "detail-type": "Scheduled Event",
      "source": "aws.events",
      "account": "123456789012",
      "time": "1970-01-01T00:00:00Z",
      "region": "us-east-1",
      "resources": [
        "arn:aws:events:us-east-1:123456789012:rule/ExampleRule"
      ],
      "detail": {}
    }
    """

    func testScheduledEventFromJSON() {
        let data = CloudwatchTests.scheduledEventPayload.data(using: .utf8)!
        var maybeEvent: Cloudwatch.Event?
        XCTAssertNoThrow(maybeEvent = try JSONDecoder().decode(Cloudwatch.Event.self, from: data))

        guard let event = maybeEvent else {
            XCTFail("Expected to have an event"); return
        }

        XCTAssertEqual(event.id, "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c")
        XCTAssertEqual(event.source, "aws.events")
        XCTAssertEqual(event.accountId, "123456789012")
        XCTAssertEqual(event.time, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.region, .us_east_1)
        XCTAssertEqual(event.resources, ["arn:aws:events:us-east-1:123456789012:rule/ExampleRule"])

        guard case Cloudwatch.Event.Detail.scheduled = event.detail else {
            XCTFail("Unexpected detail: \(event.detail)"); return
        }
    }
}
