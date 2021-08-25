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

import AWSLambdaRuntime

// introductory example, the obligatory "hello, world!"
@main
struct HelloWorldHandler: LambdaHandler {
    typealias In = String
    typealias Out = String

    init(context: Lambda.InitializationContext) async throws {
        // setup your resources that you want to reuse here.
    }

    func handle(_ event: String, context: Lambda.Context) async throws -> String {
        "hello, world"
    }
}
