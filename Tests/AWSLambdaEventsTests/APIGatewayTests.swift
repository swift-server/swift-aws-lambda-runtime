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

@testable import AWSLambdaEvents
import XCTest

class APIGatewayTests: XCTestCase {
    static let exampleGetEventBody = """
      {"httpMethod": "GET", "body": null, "resource": "/test", "requestContext": {"resourceId": "123456", "apiId": "1234567890", "resourcePath": "/test", "httpMethod": "GET", "requestId": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef", "accountId": "123456789012", "stage": "Prod", "identity": {"apiKey": null, "userArn": null, "cognitoAuthenticationType": null, "caller": null, "userAgent": "Custom User Agent String", "user": null, "cognitoIdentityPoolId": null, "cognitoAuthenticationProvider": null, "sourceIp": "127.0.0.1", "accountId": null}, "extendedRequestId": null, "path": "/test"}, "queryStringParameters": null, "multiValueQueryStringParameters": null, "headers": {"Host": "127.0.0.1:3000", "Connection": "keep-alive", "Cache-Control": "max-age=0", "Dnt": "1", "Upgrade-Insecure-Requests": "1", "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36 Edg/78.0.276.24", "Sec-Fetch-User": "?1", "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3", "Sec-Fetch-Site": "none", "Sec-Fetch-Mode": "navigate", "Accept-Encoding": "gzip, deflate, br", "Accept-Language": "en-US,en;q=0.9", "X-Forwarded-Proto": "http", "X-Forwarded-Port": "3000"}, "multiValueHeaders": {"Host": ["127.0.0.1:3000"], "Connection": ["keep-alive"], "Cache-Control": ["max-age=0"], "Dnt": ["1"], "Upgrade-Insecure-Requests": ["1"], "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36 Edg/78.0.276.24"], "Sec-Fetch-User": ["?1"], "Accept": ["text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"], "Sec-Fetch-Site": ["none"], "Sec-Fetch-Mode": ["navigate"], "Accept-Encoding": ["gzip, deflate, br"], "Accept-Language": ["en-US,en;q=0.9"], "X-Forwarded-Proto": ["http"], "X-Forwarded-Port": ["3000"]}, "pathParameters": null, "stageVariables": null, "path": "/test", "isBase64Encoded": false}
    """

    static let todoPostEventBody = """
      {"httpMethod": "POST", "body": "{\\"title\\":\\"a todo\\"}", "resource": "/todos", "requestContext": {"resourceId": "123456", "apiId": "1234567890", "resourcePath": "/todos", "httpMethod": "POST", "requestId": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef", "accountId": "123456789012", "stage": "test", "identity": {"apiKey": null, "userArn": null, "cognitoAuthenticationType": null, "caller": null, "userAgent": "Custom User Agent String", "user": null, "cognitoIdentityPoolId": null, "cognitoAuthenticationProvider": null, "sourceIp": "127.0.0.1", "accountId": null}, "extendedRequestId": null, "path": "/todos"}, "queryStringParameters": null, "multiValueQueryStringParameters": null, "headers": {"Host": "127.0.0.1:3000", "Connection": "keep-alive", "Content-Length": "18", "Pragma": "no-cache", "Cache-Control": "no-cache", "Accept": "text/plain, */*; q=0.01", "Origin": "http://todobackend.com", "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.36 Safari/537.36 Edg/79.0.309.25", "Dnt": "1", "Content-Type": "application/json", "Sec-Fetch-Site": "cross-site", "Sec-Fetch-Mode": "cors", "Referer": "http://todobackend.com/specs/index.html?http://127.0.0.1:3000/todos", "Accept-Encoding": "gzip, deflate, br", "Accept-Language": "en-US,en;q=0.9", "X-Forwarded-Proto": "http", "X-Forwarded-Port": "3000"}, "multiValueHeaders": {"Host": ["127.0.0.1:3000"], "Connection": ["keep-alive"], "Content-Length": ["18"], "Pragma": ["no-cache"], "Cache-Control": ["no-cache"], "Accept": ["text/plain, */*; q=0.01"], "Origin": ["http://todobackend.com"], "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.36 Safari/537.36 Edg/79.0.309.25"], "Dnt": ["1"], "Content-Type": ["application/json"], "Sec-Fetch-Site": ["cross-site"], "Sec-Fetch-Mode": ["cors"], "Referer": ["http://todobackend.com/specs/index.html?http://127.0.0.1:3000/todos"], "Accept-Encoding": ["gzip, deflate, br"], "Accept-Language": ["en-US,en;q=0.9"], "X-Forwarded-Proto": ["http"], "X-Forwarded-Port": ["3000"]}, "pathParameters": null, "stageVariables": null, "path": "/todos", "isBase64Encoded": false}
    """

    // MARK: - Request -

    // MARK: Decoding

    func testRequestDecodingExampleGetRequest() {
        let data = APIGatewayTests.exampleGetEventBody.data(using: .utf8)!
        var req: APIGatewayRequest?
        XCTAssertNoThrow(req = try JSONDecoder().decode(APIGatewayRequest.self, from: data))

        XCTAssertEqual(req?.path, "/test")
        XCTAssertEqual(req?.httpMethod, .GET)
    }

    func testRequestDecodingTodoPostRequest() {
        let data = APIGatewayTests.todoPostEventBody.data(using: .utf8)!
        var req: APIGatewayRequest?
        XCTAssertNoThrow(req = try JSONDecoder().decode(APIGatewayRequest.self, from: data))

        XCTAssertEqual(req?.path, "/todos")
        XCTAssertEqual(req?.httpMethod, .POST)
    }

    // MARK: - Response -

    // MARK: Encoding

    struct JSONResponse: Codable {
        let statusCode: UInt
        let headers: [String: String]?
        let body: String?
        let isBase64Encoded: Bool?
    }

    func testResponseEncoding() {
        let resp = APIGatewayResponse(
            statusCode: .ok,
            headers: ["Server": "Test"],
            body: "abc123"
        )

        var data: Data?
        XCTAssertNoThrow(data = try JSONEncoder().encode(resp))
        var json: JSONResponse?
        XCTAssertNoThrow(json = try JSONDecoder().decode(JSONResponse.self, from: XCTUnwrap(data)))

        XCTAssertEqual(json?.statusCode, resp.statusCode.code)
        XCTAssertEqual(json?.body, resp.body)
        XCTAssertEqual(json?.isBase64Encoded, resp.isBase64Encoded)
        XCTAssertEqual(json?.headers?["Server"], "Test")
    }
}
