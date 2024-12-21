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
import AWSLambdaRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

let encoder = JSONEncoder()
let runtime = LambdaRuntime {
    (event: APIGatewayV2Request, context: LambdaContext) -> APIGatewayV2Response in

    var header = HTTPHeaders()
    context.logger.debug("HTTP API Message received")

    header["content-type"] = "application/json"

    // echo the request in the response
    let data = try encoder.encode(event)
    let response = String(decoding: data, as: Unicode.UTF8.self)

    return APIGatewayV2Response(statusCode: .ok, headers: header, body: response)
}

try await runtime.run()
