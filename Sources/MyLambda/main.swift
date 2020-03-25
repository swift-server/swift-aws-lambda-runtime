//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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

// Lambda.run(StringLambda)
Lambda.run(CodableLambda)
// Lambda.run(APIGatewayProxyLambda())
// Lambda.run(FakeAPIGatewayProxyLambda())

// MARK: - Lambda Samples

func StringLambda(context: Lambda.Context, request: String, callback: (Result<String, Error>) -> Void) {
    context.logger.debug("hello, string!")
    callback(.success("hello, world!"))
}

func CodableLambda(context: Lambda.Context, request: Request, callback: (Result<Response, Error>) -> Void) {
    context.logger.info("hello, json!")
    switch request.error {
    case .none:
        callback(.success(Response(awsRequestId: context.requestId, requestId: request.requestId, status: .ok)))
    case .managed:
        callback(.success(Response(awsRequestId: context.requestId, requestId: request.requestId, status: .error)))
    case .unmanaged(let error):
        callback(.failure(UnmanagedError(description: error)))
    case .fatal:
        fatalError("crash!")
    }
}

struct APIGatewayProxyLambda: EventLoopLambdaHandler {
    public typealias In = APIGatewayRequest
    public typealias Out = APIGatewayResponse

    public init() {}

    public func handle(context: Lambda.Context, payload: APIGatewayRequest) -> EventLoopFuture<APIGatewayResponse> {
        context.logger.debug("hello, api gateway!")
        return context.eventLoop.makeSucceededFuture(APIGatewayResponse(statusCode: 200,
                                                                        headers: nil,
                                                                        multiValueHeaders: nil,
                                                                        body: "hello, world!",
                                                                        isBase64Encoded: false))
    }
}

struct FakeAPIGatewayProxyLambda: EventLoopLambdaHandler {
    public typealias In = String
    public typealias Out = String

    public init() {}

    public func handle(context: Lambda.Context, payload: String) -> EventLoopFuture<String> {
        context.logger.debug("hello, string!")
        return context.eventLoop.makeSucceededFuture("{ \"statusCode\": 200, \"body\": \"hello, world!\" }")
    }
}

struct Request: Codable {
    let requestId: String
    let error: Error

    public init(requestId: String, error: Error? = nil) {
        self.requestId = requestId
        self.error = error ?? .none
    }

    public enum Error: Codable, RawRepresentable {
        case none
        case managed
        case unmanaged(String)
        case fatal

        public init?(rawValue: String) {
            switch rawValue {
            case "none":
                self = .none
            case "managed":
                self = .managed
            case "fatal":
                self = .fatal
            default:
                self = .unmanaged(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .none:
                return "none"
            case .managed:
                return "managed"
            case .fatal:
                return "fatal"
            case .unmanaged(let error):
                return error
            }
        }
    }
}

struct Response: Codable {
    let awsRequestId: String
    let requestId: String
    let status: Status

    public init(awsRequestId: String, requestId: String, status: Status) {
        self.awsRequestId = awsRequestId
        self.requestId = requestId
        self.status = status
    }

    public enum Status: Int, Codable {
        case ok
        case error
    }
}

struct UnmanagedError: Error {
    let description: String
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
