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
import Shared

// set LOCAL_LAMBDA_SERVER_ENABLED env variable to "true" to start
// a local server simulator which will allow local debugging
@main
struct MyLambdaHandler: LambdaHandler {
    typealias Event = Request
    typealias Output = Response

    init(context: Lambda.InitializationContext) async throws {
        // setup your resources that you want to reuse for every invocation here.
    }

    func handle(_ request: Request, context: Lambda.Context) async throws -> Response {
        // TODO: something useful
        Response(message: "Hello, \(request.name)!")
    }
}
