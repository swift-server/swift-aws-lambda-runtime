//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaRuntimeCore
import XCTest

class UtilsTest: XCTestCase {
    func testGenerateXRayTraceID() {
        // the time and identifier should be in hexadecimal digits
        let invalidCharacters = CharacterSet(charactersIn: "abcdef0123456789").inverted
        let numTests = 1000
        var values = Set<String>()
        for _ in 0 ..< numTests {
            // check the format, see https://docs.aws.amazon.com/xray/latest/devguide/xray-api-sendingdata.html#xray-api-traceids)
            let traceId = AmazonHeaders.generateXRayTraceID()
            let segments = traceId.split(separator: "-")
            XCTAssertEqual(3, segments.count)
            XCTAssertEqual("1", segments[0])
            XCTAssertEqual(8, segments[1].count)
            XCTAssertNil(segments[1].rangeOfCharacter(from: invalidCharacters))
            XCTAssertEqual(24, segments[2].count)
            XCTAssertNil(segments[2].rangeOfCharacter(from: invalidCharacters))
            values.insert(traceId)
        }
        // check that the generated values are different
        XCTAssertEqual(values.count, numTests)
    }
}
