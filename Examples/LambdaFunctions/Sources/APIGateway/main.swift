//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime
import NIO

// MARK: - Run Lambda

Lambda.run(APIGatewayProxyLambda())

// MARK: - Handler, Request and Response

// FIXME: Use proper Event abstractions once added to AWSLambdaRuntime
struct APIGatewayProxyLambda: EventLoopLambdaHandler {
    public typealias In = APIGatewayRequest
    public typealias Out = APIGatewayResponse

    public func handle(context: Lambda.Context, payload: APIGatewayRequest) -> EventLoopFuture<APIGatewayResponse> {
        context.logger.debug("hello, api gateway!")
        return context.eventLoop.makeSucceededFuture(APIGatewayResponse(statusCode: 200,
                                                                        headers: nil,
                                                                        multiValueHeaders: nil,
                                                                        body: "hello, world!",
                                                                        isBase64Encoded: false))
    }
}

struct APIGatewayRequest: Codable {
    let resource: String
    let path: String
    let httpMethod: String?
    let headers: [String: String]?
    let multiValueHeaders: [String: [String]]?
    let queryStringParameters: [String: String]?
    let multiValueQueryStringParameters: [String: [String]]?
    let pathParameters: [String: String]?
    let stageVariables: [String: String]?
    let requestContext: Context?
    let body: String?
    let isBase64Encoded: Bool?

    struct Context: Codable {
        let accountId: String?
        let resourceId: String?
        let stage: String?
        let requestId: String?
        let identity: Identity?
        let resourcePath: String?
        let httpMethod: String?
        let apiId: String
    }

    struct Identity: Codable {
        let cognitoIdentityPoolId: String?
        let accountId: String?
        let cognitoIdentityId: String?
        let caller: String?
        let apiKey: String?
        let sourceIp: String?
        let cognitoAuthenticationType: String?
        let cognitoAuthenticationProvider: String?
        let userArn: String?
        let userAgent: String?
        let user: String?
    }
}

struct APIGatewayResponse: Codable {
    let statusCode: Int
    let headers: [String: String]?
    let multiValueHeaders: [String: [String]]?
    let body: String?
    let isBase64Encoded: Bool?
}
