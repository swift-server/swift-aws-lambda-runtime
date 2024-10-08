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
import SotoS3

let client = AWSClient()
let s3 = S3(client: client, region: .useast1)

func handler(event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {

    var response: APIGatewayV2Response
    do {
        context.logger.debug("Reading list of buckets")

        // read the list of buckets
        let bucketResponse = try await s3.listBuckets()
        let bucketList = bucketResponse.buckets?.compactMap { $0.name }
        response = APIGatewayV2Response(statusCode: .ok, body: bucketList?.joined(separator: "\n"))
    } catch {
        context.logger.error("\(error)")
        response = APIGatewayV2Response(statusCode: .internalServerError, body: "[ERROR] \(error)")
    }
    return response
}

let runtime = LambdaRuntime.init(body: handler)
try await runtime.run()
