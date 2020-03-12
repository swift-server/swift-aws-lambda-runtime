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

// https://github.com/aws/aws-lambda-go/blob/master/events/alb.go
public enum ALB {
    /// ALBTargetGroupRequest contains data originating from the ALB Lambda target group integration
    public struct TargetGroupRequest: DecodableBody {
        /// ALBTargetGroupRequestContext contains the information to identify the load balancer invoking the lambda
        public struct Context: Codable {
            public let elb: ELBContext
        }

        public let httpMethod: HTTPMethod
        public let path: String
        public let queryStringParameters: [String: [String]]
        public let headers: HTTPHeaders
        public let requestContext: Context
        public let isBase64Encoded: Bool
        public let body: String?
    }

    /// ELBContext contains the information to identify the ARN invoking the lambda
    public struct ELBContext: Codable {
        public let targetGroupArn: String
    }

    public struct TargetGroupResponse {
        public let statusCode: HTTPResponseStatus
        public let statusDescription: String?
        public let headers: HTTPHeaders?
        public let body: String
        public let isBase64Encoded: Bool

        public init(
            statusCode: HTTPResponseStatus,
            statusDescription: String? = nil,
            headers: HTTPHeaders? = nil,
            body: String = "",
            isBase64Encoded: Bool = false
        ) {
            self.statusCode = statusCode
            self.statusDescription = statusDescription
            self.headers = headers
            self.body = body
            self.isBase64Encoded = isBase64Encoded
        }
    }
}

// MARK: - Request -

extension ALB.TargetGroupRequest: Decodable {
    enum CodingKeys: String, CodingKey {
        case httpMethod
        case path
        case queryStringParameters
        case multiValueQueryStringParameters
        case headers
        case multiValueHeaders
        case requestContext
        case isBase64Encoded
        case body
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let method = try container.decode(String.self, forKey: .httpMethod)
        self.httpMethod = HTTPMethod(rawValue: method)

        self.path = try container.decode(String.self, forKey: .path)

        // crazy multiple headers
        // https://docs.aws.amazon.com/elasticloadbalancing/latest/application/lambda-functions.html#multi-value-headers

        if let multiValueQueryStringParameters =
            try container.decodeIfPresent([String: [String]].self, forKey: .multiValueQueryStringParameters) {
            self.queryStringParameters = multiValueQueryStringParameters
        } else {
            let singleValueQueryStringParameters = try container.decode(
                [String: String].self,
                forKey: .queryStringParameters
            )
            self.queryStringParameters = singleValueQueryStringParameters.mapValues { [$0] }
        }

        if let multiValueHeaders =
            try container.decodeIfPresent([String: [String]].self, forKey: .multiValueHeaders) {
            self.headers = HTTPHeaders(awsHeaders: multiValueHeaders)
        } else {
            let singleValueHeaders = try container.decode(
                [String: String].self,
                forKey: .headers
            )
            let multiValueHeaders = singleValueHeaders.mapValues { [$0] }
            self.headers = HTTPHeaders(awsHeaders: multiValueHeaders)
        }

        self.requestContext = try container.decode(Context.self, forKey: .requestContext)
        self.isBase64Encoded = try container.decode(Bool.self, forKey: .isBase64Encoded)

        let body = try container.decode(String.self, forKey: .body)
        self.body = body != "" ? body : nil
    }
}

// MARK: - Response -

extension ALB.TargetGroupResponse: Encodable {
    static let MultiValueHeadersEnabledKey =
        CodingUserInfoKey(rawValue: "ALB.TargetGroupResponse.MultiValueHeadersEnabledKey")!

    enum CodingKeys: String, CodingKey {
        case statusCode
        case statusDescription
        case headers
        case multiValueHeaders
        case body
        case isBase64Encoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(statusCode.code, forKey: .statusCode)

        let multiValueHeaderSupport =
            encoder.userInfo[ALB.TargetGroupResponse.MultiValueHeadersEnabledKey] as? Bool ?? false

        switch (multiValueHeaderSupport, headers) {
        case (true, .none):
            try container.encode([String: String](), forKey: .multiValueHeaders)
        case (false, .none):
            try container.encode([String: [String]](), forKey: .headers)
        case (true, .some(let headers)):
            var multiValueHeaders: [String: [String]] = [:]
            headers.forEach { name, value in
                var values = multiValueHeaders[name] ?? []
                values.append(value)
                multiValueHeaders[name] = values
            }
            try container.encode(multiValueHeaders, forKey: .multiValueHeaders)
        case (false, .some(let headers)):
            var singleValueHeaders: [String: String] = [:]
            headers.forEach { name, value in
                singleValueHeaders[name] = value
            }
            try container.encode(singleValueHeaders, forKey: .headers)
        }

        try container.encodeIfPresent(statusDescription, forKey: .statusDescription)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(isBase64Encoded, forKey: .isBase64Encoded)
    }
}

extension ALB.TargetGroupResponse {
    public init<Payload: Encodable>(
        statusCode: HTTPResponseStatus,
        statusDescription: String? = nil,
        headers: HTTPHeaders? = nil,
        payload: Payload,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        var headers = headers ?? HTTPHeaders()
        if !headers.contains(name: "Content-Type") {
            headers.add(name: "Content-Type", value: "application/json")
        }

        self.statusCode = statusCode
        self.statusDescription = statusDescription
        self.headers = headers

        let data = try encoder.encode(payload)
        self.body = String(decoding: data, as: Unicode.UTF8.self)
        self.isBase64Encoded = false
    }

    public init(
        statusCode: HTTPResponseStatus,
        statusDescription: String? = nil,
        headers: HTTPHeaders? = nil,
        bytes: [UInt8]?
    ) {
        let headers = headers ?? HTTPHeaders()

        self.statusCode = statusCode
        self.statusDescription = statusDescription
        self.headers = headers
        if let bytes = bytes {
            self.body = String(base64Encoding: bytes)
        } else {
            self.body = ""
        }
        self.isBase64Encoded = true
    }
}
