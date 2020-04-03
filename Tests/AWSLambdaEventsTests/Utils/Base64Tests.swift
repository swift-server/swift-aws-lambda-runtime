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

class Base64Tests: XCTestCase {
    // MARK: - Encoding -

    func testEncodeEmptyData() throws {
        let data = [UInt8]()
        let encodedData = String(base64Encoding: data)
        XCTAssertEqual(encodedData.count, 0)
    }

    func testBase64EncodingArrayOfNulls() throws {
        let data = Array(repeating: UInt8(0), count: 10)
        let encodedData = String(base64Encoding: data)
        XCTAssertEqual(encodedData, "AAAAAAAAAAAAAA==")
    }

    func testBase64EncodingAllTheBytesSequentially() throws {
        let data = Array(UInt8(0) ... UInt8(255))
        let encodedData = String(base64Encoding: data)
        XCTAssertEqual(encodedData, "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w==")
    }

    func testBase64UrlEncodingAllTheBytesSequentially() throws {
        let data = Array(UInt8(0) ... UInt8(255))
        let encodedData = String(base64Encoding: data, options: .base64UrlAlphabet)
        XCTAssertEqual(encodedData, "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn-AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq-wsbKztLW2t7i5uru8vb6_wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t_g4eLj5OXm5-jp6uvs7e7v8PHy8_T19vf4-fr7_P3-_w==")
    }

    // MARK: - Decoding -

    func testDecodeEmptyString() throws {
        var decoded: [UInt8]?
        XCTAssertNoThrow(decoded = try "".base64decoded())
        XCTAssertEqual(decoded?.count, 0)
    }

    func testBase64DecodingArrayOfNulls() throws {
        let expected = Array(repeating: UInt8(0), count: 10)
        var decoded: [UInt8]?
        XCTAssertNoThrow(decoded = try "AAAAAAAAAAAAAA==".base64decoded())
        XCTAssertEqual(decoded, expected)
    }

    func testBase64DecodingAllTheBytesSequentially() {
        let base64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w=="

        let expected = Array(UInt8(0) ... UInt8(255))
        var decoded: [UInt8]?
        XCTAssertNoThrow(decoded = try base64.base64decoded())

        XCTAssertEqual(decoded, expected)
    }

    func testBase64UrlDecodingAllTheBytesSequentially() {
        let base64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn-AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq-wsbKztLW2t7i5uru8vb6_wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t_g4eLj5OXm5-jp6uvs7e7v8PHy8_T19vf4-fr7_P3-_w=="

        let expected = Array(UInt8(0) ... UInt8(255))
        var decoded: [UInt8]?
        XCTAssertNoThrow(decoded = try base64.base64decoded(options: .base64UrlAlphabet))

        XCTAssertEqual(decoded, expected)
    }

    func testBase64DecodingWithPoop() {
        XCTAssertThrowsError(_ = try "💩".base64decoded()) { error in
            XCTAssertEqual(error as? Base64.DecodingError, .invalidCharacter(240))
        }
    }

    func testBase64DecodingWithInvalidLength() {
        XCTAssertThrowsError(_ = try "AAAAA".base64decoded()) { error in
            XCTAssertEqual(error as? Base64.DecodingError, .invalidLength)
        }
    }

    func testNSStringToDecode() {
        let test = "1234567"
        let nsstring = test.data(using: .utf8)!.base64EncodedString()

        XCTAssertNoThrow(try nsstring.base64decoded())
    }
}
