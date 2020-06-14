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

import Foundation

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

                let jwt: JWT
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
        public let statusCode: HTTPResponseStatus
        public let headers: HTTPHeaders?
        public let multiValueHeaders: HTTPMultiValueHeaders?
        public let body: String?
        public let isBase64Encoded: Bool?
        public let cookies: [String]?

        public init(
            statusCode: HTTPResponseStatus,
            headers: HTTPHeaders? = nil,
            multiValueHeaders: HTTPMultiValueHeaders? = nil,
            body: String? = nil,
            isBase64Encoded: Bool? = nil,
            cookies: [String]? = nil
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.multiValueHeaders = multiValueHeaders
            self.body = body
            self.isBase64Encoded = isBase64Encoded
            self.cookies = cookies
        }
    }
}

// MARK: - Codable Request body

extension APIGateway.V2.Request {
    /// Generic body decoder for JSON payloads
    ///
    /// Example:
    /// ```
    /// struct Request: Codable {
    ///   let value: String
    /// }
    ///
    /// func handle(context: Context, event: APIGateway.V2.Request, callback: @escaping (Result<APIGateway.V2.Response, Error>) -> Void) {
    ///   do {
    ///     let request: Request? = try event.decodedBody()
    ///     // Do something with `request`
    ///     callback(.success(APIGateway.V2.Response(statusCode: .ok, body:"")))
    ///   }
    ///   catch {
    ///     callback(.failure(error))
    ///   }
    /// }
    /// ```
    ///
    /// - Throws: `DecodingError` if body contains a value that couldn't be decoded
    /// - Returns: Decoded payload. Returns `nil` if body property is `nil`.
    public func decodedBody<Payload: Codable>() throws -> Payload? {
        guard let bodyString = body else {
            return nil
        }
        let data = Data(bodyString.utf8)
        return try JSONDecoder().decode(Payload.self, from: data)
    }
}

// MARK: - Codable Response body

extension APIGateway.V2.Response {
    /// Codable initializer for Response payload
    ///
    /// Example:
    /// ```
    /// struct Response: Codable {
    ///   let message: String
    /// }
    ///
    /// func handle(context: Context, event: APIGateway.V2.Request, callback: @escaping (Result<APIGateway.V2.Response, Error>) -> Void) {
    ///   ...
    ///   callback(.success(APIGateway.V2.Response(statusCode: .ok, body: Response(message: "Hello, World!")))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - statusCode: Response HTTP status code
    ///   - headers: Response HTTP headers
    ///   - multiValueHeaders: Resposne multi-value headers
    ///   - body: `Codable` response payload
    ///   - cookies: Response cookies
    /// - Throws: `EncodingError` if payload could not be encoded into a JSON string
    public init<Payload: Codable>(
        statusCode: HTTPResponseStatus,
        headers: HTTPHeaders? = nil,
        multiValueHeaders: HTTPMultiValueHeaders? = nil,
        body: Payload? = nil,
        cookies: [String]? = nil
    ) throws {
        let data = try JSONEncoder().encode(body)
        let bodyString = String(data: data, encoding: .utf8)
        self.init(statusCode: statusCode,
                  headers: headers,
                  multiValueHeaders: multiValueHeaders,
                  body: bodyString,
                  isBase64Encoded: false,
                  cookies: cookies)
    }
}
