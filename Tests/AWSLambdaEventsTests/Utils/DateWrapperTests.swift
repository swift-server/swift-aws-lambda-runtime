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

            XCTAssertEqual(context.codingPath.compactMap { $0.stringValue }, ["date"])
            XCTAssertEqual(context.debugDescription, "Expected date to be in iso8601 date format, but `\(date)` does not forfill format")
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

            XCTAssertEqual(context.codingPath.compactMap { $0.stringValue }, ["date"])
            XCTAssertEqual(context.debugDescription, "Expected date to be in iso8601 date format with fractional seconds, but `\(date)` does not forfill format")
            XCTAssertNil(context.underlyingError)
        }
    }
}
