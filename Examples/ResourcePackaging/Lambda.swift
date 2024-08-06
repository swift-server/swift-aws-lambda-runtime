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
import Foundation

// in this example we are reading from a bundled resource and responding with the contents

@main
struct MyLambda: SimpleLambdaHandler {
    func handle(_ input: String, context: LambdaContext) async throws -> String {
        guard let fileURL = Bundle.module.url(forResource: "hello", withExtension: "txt") else {
            fatalError("no file url")
        }
        return try String(contentsOf: fileURL)
    }
}
