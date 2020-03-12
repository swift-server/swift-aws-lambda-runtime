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

class DecodableBodyTests: XCTestCase {
    struct TestEvent: DecodableBody {
        let body: String?
        let isBase64Encoded: Bool
    }

    struct TestPayload: Codable {
        let hello: String
    }

    func testSimplePayloadFromEvent() {
        do {
            let event = TestEvent(body: "{\"hello\":\"world\"}", isBase64Encoded: false)
            let payload = try event.decodeBody(TestPayload.self)

            XCTAssertEqual(payload.hello, "world")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBase64PayloadFromEvent() {
        do {
            let event = TestEvent(body: "eyJoZWxsbyI6IndvcmxkIn0=", isBase64Encoded: true)
            let payload = try event.decodeBody(TestPayload.self)

            XCTAssertEqual(payload.hello, "world")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNoDataFromEvent() {
        do {
            let event = TestEvent(body: "", isBase64Encoded: false)
            _ = try event.decodeBody(TestPayload.self)

            XCTFail("Did not expect to reach this point")
        } catch DecodingError.dataCorrupted(_) {
            return // expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
