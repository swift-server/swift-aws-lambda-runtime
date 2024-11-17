//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

let functionWithUrlTemplate = #"""
    import AWSLambdaRuntime
    import AWSLambdaEvents

    // in this example we receive a FunctionURLRequest and we return a FunctionURLResponse
    // https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html#urls-payloads

    let runtime = LambdaRuntime {
            (event: FunctionURLRequest, context: LambdaContext) -> FunctionURLResponse in
            
            guard let name = event.queryStringParameters?["name"] else {
                return FunctionURLResponse(statusCode: .badRequest)
            }

    		return FunctionURLResponse(statusCode: .ok, body: #"{ "message" : "Hello \#\#(name)" } "#)
    }

    try await runtime.run()
    """#
