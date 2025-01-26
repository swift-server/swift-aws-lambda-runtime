//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime
import Foundation

let runtime = LambdaRuntime {
    (event: String, context: LambdaContext) in
    guard let fileURL = Bundle.module.url(forResource: "hello", withExtension: "txt") else {
        fatalError("no file url")
    }
    return try String(contentsOf: fileURL, encoding: .utf8)
}

try await runtime.run()
