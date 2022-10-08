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

// in this example we are receiving and responding with strings

@main
struct MyLambda: LambdaHandler {
    func handle(_ input: String, context: LambdaContext) async throws -> String {
        // as an example, respond with the input's reversed
        String(input.reversed())
    }
}
