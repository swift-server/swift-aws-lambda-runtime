//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html

/// This is a simplified version of the FunctionURLRequest structure, with no dependencies on the HTTPType module.
/// This file is copied from AWS Lambda Event project at https://github.com/swift-server/swift-aws-lambda-events

/// FunctionURLRequest contains data coming from a bare Lambda Function URL
public struct FunctionURLRequest: Codable, Sendable {
    public struct Context: Codable, Sendable {
        public struct Authorizer: Codable, Sendable {
            public struct IAMAuthorizer: Codable, Sendable {
                public let accessKey: String

                public let accountId: String
                public let callerId: String
                public let cognitoIdentity: String?

                public let principalOrgId: String?

                public let userArn: String
                public let userId: String
            }

            public let iam: IAMAuthorizer?
        }

        public struct HTTP: Codable, Sendable {
            public let method: String
            public let path: String
            public let `protocol`: String
            public let sourceIp: String
            public let userAgent: String
        }

        public let accountId: String
        public let apiId: String
        public let authentication: String?
        public let authorizer: Authorizer?
        public let domainName: String
        public let domainPrefix: String
        public let http: HTTP

        public let requestId: String
        public let routeKey: String
        public let stage: String

        public let time: String
        public let timeEpoch: Int
    }

    public let version: String

    public let routeKey: String
    public let rawPath: String
    public let rawQueryString: String
    public let cookies: [String]?
    public let headers: [String: String]
    public let queryStringParameters: [String: String]?

    public let requestContext: Context

    public let body: String?
    public let pathParameters: [String: String]?
    public let isBase64Encoded: Bool

    public let stageVariables: [String: String]?
}

// MARK: - Response -

public struct FunctionURLResponse: Codable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]?
    public var body: String?
    public let cookies: [String]?
    public var isBase64Encoded: Bool?

    public init(
        statusCode: Int,
        headers: [String: String]? = nil,
        body: String? = nil,
        cookies: [String]? = nil,
        isBase64Encoded: Bool? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.cookies = cookies
        self.isBase64Encoded = isBase64Encoded
    }
}
