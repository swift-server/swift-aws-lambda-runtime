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

public struct MyHandler: Sendable {

    public func handler(event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        context.logger.debug("HTTP API Message received")
        context.logger.trace("Event: \(event)")

        var header = HTTPHeaders()
        header["content-type"] = "application/json"

        // API Gateway sends text or URL encoded data as a Base64 encoded string
        if let base64EncodedString = event.body,
            let decodedData = Data(base64Encoded: base64EncodedString),
            let decodedString = String(data: decodedData, encoding: .utf8)
        {

            // call our business code to process the payload and return a response
            return APIGatewayV2Response(statusCode: .ok, headers: header, body: decodedString.uppercasedFirst())
        } else {
            return APIGatewayV2Response(statusCode: .badRequest)
        }
    }
}

let runtime = LambdaRuntime(body: MyHandler().handler)
try await runtime.run()
