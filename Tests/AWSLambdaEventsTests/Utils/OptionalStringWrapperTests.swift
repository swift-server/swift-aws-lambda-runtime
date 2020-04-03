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

class OptionStaringWrapperTests: XCTestCase {
    func testMissing() {
        struct TestEvent: Decodable {
            @OptionalStringCoding
            var value: String?

            public enum CodingKeys: String, CodingKey {
                case value
            }
        }

        let json = #"{}"#
        var event: TestEvent!
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))
        XCTAssertNil(event.value)
    }

    func testNull() {
        struct TestEvent: Decodable {
            @OptionalStringCoding
            var value: String?

            public enum CodingKeys: String, CodingKey {
                case value
            }
        }

        let json = #"{"value": null}"#
        var event: TestEvent!
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))
        XCTAssertNil(event.value)
    }

    func testEmpty() {
        struct TestEvent: Decodable {
            @OptionalStringCoding
            var value: String?
        }

        let json = #"{"value": ""}"#
        var event: TestEvent!
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))
        XCTAssertNil(event.value)
    }

    func testValue() {
        struct TestEvent: Decodable {
            @OptionalStringCoding
            var value: String?
        }

        let json = #"{"value": "foo"}"#
        var event: TestEvent!
        XCTAssertNoThrow(event = try JSONDecoder().decode(TestEvent.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(event.value, "foo")
    }
}
