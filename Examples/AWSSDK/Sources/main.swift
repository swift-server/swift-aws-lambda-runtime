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

import AWSLambdaRuntime
import AWSLambdaEvents

import AWSS3


func handler(event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {

    var response: APIGatewayV2Response
    do {
        // read the list of buckets 
        context.logger.debug("Reading list of buckets")
        let client = try await S3Client()
        let output = try await client.listBuckets(input: ListBucketsInput())
        let bucketList = output.buckets?.compactMap { $0.name }
        response = APIGatewayV2Response(statusCode: .ok, body: bucketList?.joined(separator: "\n"))
    } catch {
        context.logger.error("\(error)")
        response = APIGatewayV2Response(statusCode: .internalServerError, body: "[ERROR] \(error)")
    }
    return response
}

let runtime = LambdaRuntime.init(body: handler)
try await runtime.run()
