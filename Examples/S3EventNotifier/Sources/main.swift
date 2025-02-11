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
import AsyncHTTPClient

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

let httpClient = HTTPClient.shared

enum LambdaError: Error {
    case noNotificationRecord
    case missingEnvVar(name: String)

    var description: String {
        switch self {
        case .noNotificationRecord:
            "No notification record in S3 event"
        case .missingEnvVar(let name):
            "Missing env var named \(name)"
        }
    }
}

let runtime = LambdaRuntime { (event: S3Event, context: LambdaContext) async throws -> APIGatewayV2Response in
    do {
        context.logger.debug("Received S3 event: \(event)")

        guard let s3NotificationRecord = event.records.first else {
            throw LambdaError.noNotificationRecord
        }

        let bucket = s3NotificationRecord.s3.bucket.name
        let key = s3NotificationRecord.s3.object.key.replacingOccurrences(of: "+", with: " ")

        guard let apiURL = ProcessInfo.processInfo.environment["API_URL"] else {
            throw LambdaError.missingEnvVar(name: "API_URL")
        }

        let body = """
            {
                "bucket": "\(bucket)",
                "key": "\(key)"
            }
            """

        context.logger.debug("Sending request to \(apiURL) with body \(body)")

        var request = HTTPClientRequest(url: "\(apiURL)/upload-complete/")
        request.method = .POST
        request.headers = [
            "Content-Type": "application/json"
        ]
        request.body = .bytes(.init(string: body))

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        return APIGatewayV2Response(
            statusCode: .ok,
            body: "Lambda terminated successfully. API responded with: Status: \(response.status), Body: \(response.body)"
        )
    } catch let error as LambdaError {
        context.logger.error("\(error.description)")
        return APIGatewayV2Response(statusCode: .internalServerError, body: "[ERROR] \(error.description)")
    } catch {
        context.logger.error("\(error)")
        return APIGatewayV2Response(statusCode: .internalServerError, body: "[ERROR] \(error)")
    }
}

try await runtime.run()
