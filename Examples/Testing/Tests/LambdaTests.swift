//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime
import AWSLambdaTesting
@testable import MyLambda
import XCTest

class LambdaTest: XCTestCase {
    func testIt() async throws {
        let input = UUID().uuidString
        let result = try await Lambda.test(MyLambda.self, with: input)
        XCTAssertEqual(result, String(input.reversed()))
    }
}
