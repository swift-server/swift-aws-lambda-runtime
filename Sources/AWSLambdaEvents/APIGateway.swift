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

import class Foundation.JSONEncoder
import NIOHTTP1

// https://github.com/aws/aws-lambda-go/blob/master/events/apigw.go

public enum APIGateway {
    /// APIGatewayRequest contains data coming from the API Gateway
    public struct Request: DecodableBody {
        public struct Context: Codable {
            public struct Identity: Codable {
                public let cognitoIdentityPoolId: String?

                public let apiKey: String?
                public let userArn: String?
                public let cognitoAuthenticationType: String?
                public let caller: String?
                public let userAgent: String?
                public let user: String?

                public let cognitoAuthenticationProvider: String?
                public let sourceIp: String?
                public let accountId: String?
            }

            public let resourceId: String
            public let apiId: String
            public let resourcePath: String
            public let httpMethod: String
            public let requestId: String
            public let accountId: String
            public let stage: String

            public let identity: Identity
            public let extendedRequestId: String?
            public let path: String
        }

        public let resource: String
        public let path: String
        public let httpMethod: HTTPMethod

        public let queryStringParameters: [String: String]?
        public let multiValueQueryStringParameters: [String: [String]]?
        public let headers: HTTPHeaders
        public let pathParameters: [String: String]?
        public let stageVariables: [String: String]?

        public let requestContext: Context
        public let body: String?
        public let isBase64Encoded: Bool
    }

    public struct Response {
        public let statusCode: HTTPResponseStatus
        public let headers: HTTPHeaders?
        public let body: String?
        public let isBase64Encoded: Bool?

        public init(
            statusCode: HTTPResponseStatus,
            headers: HTTPHeaders? = nil,
            body: String? = nil,
            isBase64Encoded: Bool? = nil
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
            self.isBase64Encoded = isBase64Encoded
        }
    }
}

// MARK: - Request -

extension APIGateway.Request: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource
        case path
        case httpMethod

        case queryStringParameters
        case multiValueQueryStringParameters
        case headers
        case multiValueHeaders
        case pathParameters
        case stageVariables

        case requestContext
        case body
        case isBase64Encoded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let method = try container.decode(String.self, forKey: .httpMethod)
        self.httpMethod = HTTPMethod(rawValue: method)
        self.path = try container.decode(String.self, forKey: .path)
        self.resource = try container.decode(String.self, forKey: .resource)

        self.queryStringParameters = try container.decodeIfPresent(
            [String: String].self,
            forKey: .queryStringParameters
        )
        self.multiValueQueryStringParameters = try container.decodeIfPresent(
            [String: [String]].self,
            forKey: .multiValueQueryStringParameters
        )

        let awsHeaders = try container.decode([String: [String]].self, forKey: .multiValueHeaders)
        self.headers = HTTPHeaders(awsHeaders: awsHeaders)

        self.pathParameters = try container.decodeIfPresent([String: String].self, forKey: .pathParameters)
        self.stageVariables = try container.decodeIfPresent([String: String].self, forKey: .stageVariables)

        self.requestContext = try container.decode(Context.self, forKey: .requestContext)
        self.isBase64Encoded = try container.decode(Bool.self, forKey: .isBase64Encoded)
        self.body = try container.decodeIfPresent(String.self, forKey: .body)
    }
}

// MARK: - Response -

extension APIGateway.Response: Encodable {
    enum CodingKeys: String, CodingKey {
        case statusCode
        case headers
        case body
        case isBase64Encoded
    }

    private struct HeaderKeys: CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int? {
            fatalError("unexpected use")
        }

        init?(intValue: Int) {
            fatalError("unexpected use")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(statusCode.code, forKey: .statusCode)

        if let headers = headers {
            var headerContainer = container.nestedContainer(keyedBy: HeaderKeys.self, forKey: .headers)
            try headers.forEach { name, value in
                try headerContainer.encode(value, forKey: HeaderKeys(stringValue: name)!)
            }
        }

        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(isBase64Encoded, forKey: .isBase64Encoded)
    }
}

extension APIGateway.Response {
    public init<Payload: Encodable>(
        statusCode: HTTPResponseStatus,
        headers: HTTPHeaders? = nil,
        payload: Payload,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        var headers = headers ?? HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")

        self.statusCode = statusCode
        self.headers = headers

        let data = try encoder.encode(payload)
        self.body = String(decoding: data, as: Unicode.UTF8.self)
        self.isBase64Encoded = false
    }

    public init(
        statusCode: HTTPResponseStatus,
        headers: HTTPHeaders? = nil,
        bytes: [UInt8]?
    ) {
        let headers = headers ?? HTTPHeaders()

        self.statusCode = statusCode
        self.headers = headers
        if let bytes = bytes {
            self.body = String(base64Encoding: bytes)
        } else {
            self.body = ""
        }
        self.isBase64Encoded = true
    }
}
