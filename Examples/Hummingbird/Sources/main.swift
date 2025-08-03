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

import AWSLambdaEvents
import HummingbirdLambda
import Logging

typealias AppRequestContext = BasicLambdaRequestContext<APIGatewayV2Request>
let router = Router(context: AppRequestContext.self)

router.get("hello") { _, _ in
    "Hello"
}

let lambda = APIGatewayV2LambdaFunction(router: router)
try await lambda.runService()
