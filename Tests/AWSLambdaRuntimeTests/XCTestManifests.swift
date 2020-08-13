//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if !canImport(ObjectiveC)
import XCTest

extension CodableLambdaTest {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__CodableLambdaTest = [
        ("testCodableClosureWrapper", testCodableClosureWrapper),
        ("testCodableVoidClosureWrapper", testCodableVoidClosureWrapper),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CodableLambdaTest.__allTests__CodableLambdaTest),
    ]
}
#endif
