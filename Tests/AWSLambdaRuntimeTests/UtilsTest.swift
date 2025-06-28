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

import Testing

@testable import AWSLambdaRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct UtilsTest {
    @Test
    func testGenerateXRayTraceID() {
        // the time and identifier should be in hexadecimal digits
        let invalidCharacters = CharacterSet(charactersIn: "abcdef0123456789").inverted
        let numTests = 1000
        var values = Set<String>()
        for _ in 0..<numTests {
            // check the format, see https://docs.aws.amazon.com/xray/latest/devguide/xray-api-sendingdata.html#xray-api-traceids)
            let traceId = AmazonHeaders.generateXRayTraceID()
            let segments = traceId.split(separator: "-")
            #expect(segments.count == 3)
            #expect(segments[0] == "1")
            #expect(segments[1].count == 8)
            #expect(segments[1].rangeOfCharacter(from: invalidCharacters) == nil)
            #expect(segments[2].count == 24)
            #expect(segments[2].rangeOfCharacter(from: invalidCharacters) == nil)
            values.insert(traceId)
        }
        // check that the generated values are different
        #expect(values.count == numTests)
    }
}
