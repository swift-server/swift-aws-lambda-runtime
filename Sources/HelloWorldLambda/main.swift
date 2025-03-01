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

struct Request: Codable {
    var name: String
}

struct Response: Codable {
    var greeting: String
}

let runtime = LambdaRuntime { (_ request: Request, context) -> Response in
    Response(greeting: "Hello \(request.name)")
}

try await runtime.run()
