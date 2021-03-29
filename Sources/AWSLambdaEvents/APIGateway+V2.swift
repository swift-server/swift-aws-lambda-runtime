//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension APIGateway {
    public struct V2 {}
}

extension APIGateway.V2 {
    /// APIGateway.V2.Request contains data coming from the new HTTP API Gateway
    public struct Request: Codable {
        /// Context contains the information to identify the AWS account and resources invoking the Lambda function.
        public struct Context: Codable {
            public struct HTTP: Codable {
                public let method: HTTPMethod
                public let path: String
                public let `protocol`: String
                public let sourceIp: String
                public let userAgent: String
            }

            /// Authorizer contains authorizer information for the request context.
            public struct Authorizer: Codable {
                /// JWT contains JWT authorizer information for the request context.
                public struct JWT: Codable {
                    public let claims: [String: String]
                    public let scopes: [String]?
                }

                public let jwt: JWT
            }

            public let accountId: String
            public let apiId: String
            public let domainName: String
            public let domainPrefix: String
            public let stage: String
            public let requestId: String

            public let http: HTTP
            public let authorizer: Authorizer?

            /// The request time in format: 23/Apr/2020:11:08:18 +0000
            public let time: String
            public let timeEpoch: UInt64
        }

        public let version: String
        public let routeKey: String
        public let rawPath: String
        public let rawQueryString: String

        public let cookies: [String]?
        public let headers: HTTPHeaders
        public let queryStringParameters: [String: String]?
        public let pathParameters: [String: String]?

        public let context: Context
        public let stageVariables: [String: String]?

        public let body: String?
        public let isBase64Encoded: Bool

        enum CodingKeys: String, CodingKey {
            case version
            case routeKey
            case rawPath
            case rawQueryString

            case cookies
            case headers
            case queryStringParameters
            case pathParameters

            case context = "requestContext"
            case stageVariables

            case body
            case isBase64Encoded
        }
    }
}

extension APIGateway.V2 {
    public struct Response: Codable {
        public var statusCode: HTTPResponseStatus
        public var headers: HTTPHeaders?
        public var body: String?
        public var isBase64Encoded: Bool?
        public var cookies: [String]?

        public init(
            statusCode: HTTPResponseStatus,
            headers: HTTPHeaders? = nil,
            body: String? = nil,
            isBase64Encoded: Bool? = nil,
            cookies: [String]? = nil
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
            self.isBase64Encoded = isBase64Encoded
            self.cookies = cookies
        }
    }
}
