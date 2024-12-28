//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@testable import APIGatewayLambda  // to access the business code

let valuesToTest: [(String, String)] = [
    ("hello world", "Hello world"),  // happy path
    ("", ""),  // Empty string
    ("a", "A"),  // Single character
    ("A", "A"),  // Single uppercase character
    ("HELLO WORLD", "Hello world"),  // All uppercase
    ("hello world", "Hello world"),  // All lowercase
    ("hElLo WoRlD", "Hello world"),  // Mixed case
    ("123abc", "123abc"),  // Numeric string
    ("!@#abc", "!@#abc"),  // Special characters
]

@Suite("Business Tests")
class BusinessTests {

    @Test("Uppercased First", arguments: valuesToTest)
    func uppercasedFirst(_ arg: (String, String)) {
        let input = arg.0
        let expectedOutput = arg.1
        #expect(input.uppercasedFirst() == expectedOutput)
    }
}
