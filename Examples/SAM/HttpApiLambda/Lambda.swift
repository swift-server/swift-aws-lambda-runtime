// ===----------------------------------------------------------------------===//
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
// ===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation

@main
struct HttpApiLambda: SimpleLambdaHandler {    
    init() {}
    init(context: LambdaInitializationContext) async throws {
        context.logger.info(
            "Log Level env var : \(ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info" )")
    }

    // the return value must be either APIGatewayV2Response or any Encodable struct
    func handle(_ event: APIGatewayV2Request, context: AWSLambdaRuntimeCore.LambdaContext) async throws -> APIGatewayV2Response {
        
        var header = HTTPHeaders()
        do {
            context.logger.debug("HTTP API Message received")
            
            header["content-type"] = "application/json"
            
            // echo the request in the response
            let data = try JSONEncoder().encode(event)
            let response = String(data: data, encoding: .utf8)
            
            // if you want contronl on the status code and headers, return an APIGatewayV2Response
            // otherwise, just return any Encodable struct, the runtime will wrap it for you
            return APIGatewayV2Response(statusCode: .ok, headers: header, body: response)
            
        } catch {
            // should never happen as the decoding was made by the runtime
            // when the input event is malformed, this function is not even called
            header["content-type"] = "text/plain"
            return APIGatewayV2Response(statusCode: .badRequest, headers: header, body: "\(error.localizedDescription)")
            
        }
    }
}
