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

class APIGatewayV2Tests: XCTestCase {
    static let exampleGetEventBody = """
    {
        "routeKey":"GET /hello",
        "version":"2.0",
        "rawPath":"/hello",
        "stageVariables":{
            "foo":"bar"
        },
        "requestContext":{
            "timeEpoch":1587750461466,
            "domainPrefix":"hello",
            "authorizer":{
                "jwt":{
                    "scopes":[
                        "hello"
                    ],
                    "claims":{
                        "aud":"customers",
                        "iss":"https://hello.test.com/",
                        "iat":"1587749276",
                        "exp":"1587756476"
                    }
                }
            },
            "accountId":"0123456789",
            "stage":"$default",
            "domainName":"hello.test.com",
            "apiId":"pb5dg6g3rg",
            "requestId":"LgLpnibOFiAEPCA=",
            "http":{
                "path":"/hello",
                "userAgent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
                "method":"GET",
                "protocol":"HTTP/1.1",
                "sourceIp":"91.64.117.86"
            },
            "time":"24/Apr/2020:17:47:41 +0000"
        },
        "isBase64Encoded":false,
        "rawQueryString":"foo=bar",
        "queryStringParameters":{
            "foo":"bar"
        },
        "headers":{
            "x-forwarded-proto":"https",
            "x-forwarded-for":"91.64.117.86",
            "x-forwarded-port":"443",
            "authorization":"Bearer abc123",
            "host":"hello.test.com",
            "x-amzn-trace-id":"Root=1-5ea3263d-07c5d5ddfd0788bed7dad831",
            "user-agent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
            "content-length":"0"
        }
    }
    """

    // MARK: - Request -

    // MARK: Decoding

    func testRequestDecodingExampleGetRequest() {
        let data = APIGatewayV2Tests.exampleGetEventBody.data(using: .utf8)!
        var req: APIGatewayV2Request?
        XCTAssertNoThrow(req = try JSONDecoder().decode(APIGatewayV2Request.self, from: data))

        XCTAssertEqual(req?.rawPath, "/hello")
        XCTAssertEqual(req?.context.http.method, .GET)
        XCTAssertEqual(req?.queryStringParameters?.count, 1)
        XCTAssertEqual(req?.rawQueryString, "foo=bar")
        XCTAssertEqual(req?.headers.count, 8)
        XCTAssertNil(req?.body)
    }
}
