//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright SwiftAWSLambdaRuntime project authors
// Copyright (c) Amazon.com, Inc. or its affiliates.
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime

let runtime = LambdaRuntime {
    (event: APIGatewayV2Request, context: LambdaContext) -> APIGatewayV2Response in

    var header = HTTPHeaders()
    context.logger.debug("HTTP API Message received")

    header["content-type"] = "application/json"

    // echo the request in the response
    return try APIGatewayV2Response(statusCode: .ok, headers: header, encodableBody: event)
}

try await runtime.run()
