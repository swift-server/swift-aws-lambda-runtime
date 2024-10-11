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
@preconcurrency import AWSS3

let client = try await S3Client()

let runtime = LambdaRuntime {
    (event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response in

    var response: APIGatewayV2Response
    do {
        // read the list of buckets
        context.logger.debug("Reading list of buckets")
        let output = try await client.listBuckets(input: ListBucketsInput())
        let bucketList = output.buckets?.compactMap { $0.name }
        response = APIGatewayV2Response(statusCode: .ok, body: bucketList?.joined(separator: "\n"))
    } catch {
        context.logger.error("\(error)")
        response = APIGatewayV2Response(statusCode: .internalServerError, body: "[ERROR] \(error)")
    }
    return response
}

try await runtime.run()
