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

class DateWrapperTests: XCTestCase {
    func testISO8601CodingWrapperSuccess() {
        struct TestEvent: Decodable {
            @ISO8601Coding
            var date: Date
        }

        let json = #"{"date":"2020-03-26T16:53:05Z"}"#
        var event: TestEvent?
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))

        XCTAssertEqual(event?.date, Date(timeIntervalSince1970: 1_585_241_585))
    }

    func testISO8601CodingWrapperFailure() {
        struct TestEvent: Decodable {
            @ISO8601Coding
            var date: Date
        }

        let date = "2020-03-26T16:53:05" // missing Z at end
        let json = #"{"date":"\#(date)"}"#
        XCTAssertThrowsError(_ = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Unexpected error: \(error)"); return
            }

            XCTAssertEqual(context.codingPath.map(\.stringValue), ["date"])
            XCTAssertEqual(context.debugDescription, "Expected date to be in ISO8601 date format, but `\(date)` is not in the correct format")
            XCTAssertNil(context.underlyingError)
        }
    }

    func testISO8601WithFractionalSecondsCodingWrapperSuccess() {
        struct TestEvent: Decodable {
            @ISO8601WithFractionalSecondsCoding
            var date: Date
        }

        let json = #"{"date":"2020-03-26T16:53:05.123Z"}"#
        var event: TestEvent?
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))

        XCTAssertEqual(event?.date, Date(timeIntervalSince1970: 1_585_241_585.123))
    }

    func testISO8601WithFractionalSecondsCodingWrapperFailure() {
        struct TestEvent: Decodable {
            @ISO8601WithFractionalSecondsCoding
            var date: Date
        }

        let date = "2020-03-26T16:53:05Z" // missing fractional seconds
        let json = #"{"date":"\#(date)"}"#
        XCTAssertThrowsError(_ = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Unexpected error: \(error)"); return
            }

            XCTAssertEqual(context.codingPath.map(\.stringValue), ["date"])
            XCTAssertEqual(context.debugDescription, "Expected date to be in ISO8601 date format with fractional seconds, but `\(date)` is not in the correct format")
            XCTAssertNil(context.underlyingError)
        }
    }

    func testRFC5322DateTimeCodingWrapperSuccess() {
        struct TestEvent: Decodable {
            @RFC5322DateTimeCoding
            var date: Date
        }

        let json = #"{"date":"Thu, 5 Apr 2012 23:47:37 +0200"}"#
        var event: TestEvent?
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))

        XCTAssertEqual(event?.date.description, "2012-04-05 21:47:37 +0000")
    }

    func testRFC5322DateTimeCodingWrapperWithExtraTimeZoneSuccess() {
        struct TestEvent: Decodable {
            @RFC5322DateTimeCoding
            var date: Date
        }

        let json = #"{"date":"Fri, 26 Jun 2020 03:04:03 -0500 (CDT)"}"#
        var event: TestEvent?
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))

        XCTAssertEqual(event?.date.description, "2020-06-26 08:04:03 +0000")
    }

    func testRFC5322DateTimeCodingWrapperWithAlphabeticTimeZoneSuccess() {
        struct TestEvent: Decodable {
            @RFC5322DateTimeCoding
            var date: Date
        }

        let json = #"{"date":"Fri, 26 Jun 2020 03:04:03 CDT"}"#
        var event: TestEvent?
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))

        XCTAssertEqual(event?.date.description, "2020-06-26 08:04:03 +0000")
    }

    func testRFC5322DateTimeCodingWrapperFailure() {
        struct TestEvent: Decodable {
            @RFC5322DateTimeCoding
            var date: Date
        }

        let date = "Thu, 5 Apr 2012 23:47 +0200" // missing seconds
        let json = #"{"date":"\#(date)"}"#
        XCTAssertThrowsError(_ = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Unexpected error: \(error)"); return
            }

            XCTAssertEqual(context.codingPath.map(\.stringValue), ["date"])
            XCTAssertEqual(context.debugDescription, "Expected date to be in RFC5322 date-time format with fractional seconds, but `\(date)` is not in the correct format")
            XCTAssertNil(context.underlyingError)
        }
    }
}
