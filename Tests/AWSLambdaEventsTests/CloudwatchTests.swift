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
    static func eventBody(type: String, details: String) -> String {
        """
        {
          "id": "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c",
          "detail-type": "\(type)",
          "source": "aws.events",
          "account": "123456789012",
          "time": "1970-01-01T00:00:00Z",
          "region": "us-east-1",
          "resources": [
            "arn:aws:events:us-east-1:123456789012:rule/ExampleRule"
          ],
          "detail": \(details)
        }
        """
    }

    func testScheduledEventFromJSON() {
        let eventBody = CloudwatchTests.eventBody(type: Cloudwatch.Scheduled.name, details: "{}")
        let data = eventBody.data(using: .utf8)!
        var maybeEvent: Cloudwatch.ScheduledEvent?
        XCTAssertNoThrow(maybeEvent = try JSONDecoder().decode(Cloudwatch.ScheduledEvent.self, from: data))

        guard let event = maybeEvent else {
            return XCTFail("Expected to have an event")
        }

        XCTAssertEqual(event.id, "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c")
        XCTAssertEqual(event.source, "aws.events")
        XCTAssertEqual(event.accountId, "123456789012")
        XCTAssertEqual(event.time, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.region, .us_east_1)
        XCTAssertEqual(event.resources, ["arn:aws:events:us-east-1:123456789012:rule/ExampleRule"])
    }

    func testEC2InstanceStateChangeNotificationEventFromJSON() {
        let eventBody = CloudwatchTests.eventBody(type: Cloudwatch.EC2.InstanceStateChangeNotification.name,
                                                  details: "{ \"instance-id\": \"0\", \"state\": \"stopping\" }")
        let data = eventBody.data(using: .utf8)!
        var maybeEvent: Cloudwatch.EC2.InstanceStateChangeNotificationEvent?
        XCTAssertNoThrow(maybeEvent = try JSONDecoder().decode(Cloudwatch.EC2.InstanceStateChangeNotificationEvent.self, from: data))

        guard let event = maybeEvent else {
            return XCTFail("Expected to have an event")
        }

        XCTAssertEqual(event.id, "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c")
        XCTAssertEqual(event.source, "aws.events")
        XCTAssertEqual(event.accountId, "123456789012")
        XCTAssertEqual(event.time, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.region, .us_east_1)
        XCTAssertEqual(event.resources, ["arn:aws:events:us-east-1:123456789012:rule/ExampleRule"])
        XCTAssertEqual(event.detail.instanceId, "0")
        XCTAssertEqual(event.detail.state, .stopping)
    }

    func testEC2SpotInstanceInterruptionNoticeEventFromJSON() {
        let eventBody = CloudwatchTests.eventBody(type: Cloudwatch.EC2.SpotInstanceInterruptionNotice.name,
                                                  details: "{ \"instance-id\": \"0\", \"instance-action\": \"terminate\" }")
        let data = eventBody.data(using: .utf8)!
        var maybeEvent: Cloudwatch.EC2.SpotInstanceInterruptionNoticeEvent?
        XCTAssertNoThrow(maybeEvent = try JSONDecoder().decode(Cloudwatch.EC2.SpotInstanceInterruptionNoticeEvent.self, from: data))

        guard let event = maybeEvent else {
            return XCTFail("Expected to have an event")
        }

        XCTAssertEqual(event.id, "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c")
        XCTAssertEqual(event.source, "aws.events")
        XCTAssertEqual(event.accountId, "123456789012")
        XCTAssertEqual(event.time, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.region, .us_east_1)
        XCTAssertEqual(event.resources, ["arn:aws:events:us-east-1:123456789012:rule/ExampleRule"])
        XCTAssertEqual(event.detail.instanceId, "0")
        XCTAssertEqual(event.detail.action, .terminate)
    }

    func testCustomEventFromJSON() {
        struct Custom: CloudwatchDetail {
            public static let name = "Custom"

            let name: String
        }

        let eventBody = CloudwatchTests.eventBody(type: Custom.name, details: "{ \"name\": \"foo\" }")
        let data = eventBody.data(using: .utf8)!
        var maybeEvent: Cloudwatch.Event<Custom>?
        XCTAssertNoThrow(maybeEvent = try JSONDecoder().decode(Cloudwatch.Event<Custom>.self, from: data))

        guard let event = maybeEvent else {
            return XCTFail("Expected to have an event")
        }

        XCTAssertEqual(event.id, "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c")
        XCTAssertEqual(event.source, "aws.events")
        XCTAssertEqual(event.accountId, "123456789012")
        XCTAssertEqual(event.time, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(event.region, .us_east_1)
        XCTAssertEqual(event.resources, ["arn:aws:events:us-east-1:123456789012:rule/ExampleRule"])
        XCTAssertEqual(event.detail.name, "foo")
    }

    func testUnregistredType() {
        let eventBody = CloudwatchTests.eventBody(type: UUID().uuidString, details: "{}")
        let data = eventBody.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Cloudwatch.ScheduledEvent.self, from: data)) { error in
            XCTAssert(error is Cloudwatch.DetailTypeMismatch, "expected DetailTypeMismatch but received \(error)")
        }
    }

    func testTypeMismatch() {
        let eventBody = CloudwatchTests.eventBody(type: Cloudwatch.EC2.InstanceStateChangeNotification.name,
                                                  details: "{ \"instance-id\": \"0\", \"state\": \"stopping\" }")
        let data = eventBody.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Cloudwatch.ScheduledEvent.self, from: data)) { error in
            XCTAssert(error is Cloudwatch.DetailTypeMismatch, "expected DetailTypeMismatch but received \(error)")
        }
    }
}
