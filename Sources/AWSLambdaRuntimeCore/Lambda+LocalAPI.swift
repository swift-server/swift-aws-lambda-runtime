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

#if DEBUG
import AWSLambdaEvents
import NIO // ByteBuffer
import NIOFoundationCompat
import NIOHTTP1 // HTTPRequestHead

import struct Foundation.URLComponents

struct APIGatewayMapping: DataMapping {
    func mapRequest(requestId: String, head: HTTPRequestHead, body: ByteBuffer?) throws -> ByteBuffer {
        let request = APIGateway.Request(requestId: requestId, head: head, body: body)
        return try jsonEncoder.encode(request) as ByteBuffer
    }

    func mapResponse(buffer: ByteBuffer?) throws -> Response {
        guard let buffer = buffer else {
            preconditionFailure("nil response")
        }
        let response = try jsonDecoder.decode(APIGateway.Response.self, from: buffer)
        return Response(
            status: response.statusCode.code,
            headers: response.headers?.map { ($0.key, $0.value) },
            body: response.body.flatMap(ByteBuffer.init)
        )
    }
}

struct APIGatewayV2Mapping: DataMapping {
    func mapRequest(requestId: String, head: HTTPRequestHead, body: ByteBuffer?) throws -> ByteBuffer {
        fatalError("not implemented")
    }

    func mapResponse(buffer: ByteBuffer?) throws -> Response {
        fatalError("not implemented")
    }
}

private extension APIGateway.Request {
    init(requestId: String, head: HTTPRequestHead, body: ByteBuffer?) {
        let path = head.uri
        let httpMethod: AWSLambdaEvents.HTTPMethod = AWSLambdaEvents.HTTPMethod(rawValue: head.method.rawValue)!

        let url = URLComponents(string: head.uri)
        let queryItems = url?.queryItems
        let queryStringParameters = queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
            .compactMapValues { $0 }
        let multiValueQueryStringParameters = queryItems.flatMap {
            Dictionary(grouping: $0, by: { $0.name }).mapValues { $0.compactMap { $0.value } }
        }

        let headers = Dictionary(head.headers.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last })
        let multiValueHeaders = Dictionary(grouping: head.headers, by: { $0.name }).mapValues { $0.map { $0.value } }

        var body = body

        let context = APIGateway.Request.Context(
            resourceId: "mockId",
            apiId: "mock",
            resourcePath: "/{proxy+}",
            httpMethod: head.method.rawValue,
            requestId: requestId,
            accountId: "",
            stage: "local",
            path: path
        )

        self.init(
            resource: "/{proxy+}",
            path: path,
            httpMethod: httpMethod,
            queryStringParameters: queryStringParameters,
            multiValueQueryStringParameters: multiValueQueryStringParameters,
            headers: headers,
            multiValueHeaders: multiValueHeaders,
            requestContext: context,
            body: body?.readString()
        )
    }
}

private extension ByteBuffer {
    mutating func readString() -> String? {
        self.readString(length: readableBytes)
    }
}

// MARK: - JSON

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

private extension JSONEncoder {
    func encode<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encode(value), as: UTF8.self)
    }

    func encode<T: Encodable>(_ value: T) throws -> ByteBuffer {
        ByteBuffer(string: try encode(value) as String)
    }
}

private extension JSONDecoder {
    func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        try decode(type, from: Data(string.utf8))
    }

    func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        try buffer.getJSONDecodable(T.self,
                                    decoder: self,
                                    at: buffer.readerIndex,
                                    length: buffer.readableBytes)! // must work, enough readable bytes
    }
}

private let jsonEncoder = JSONEncoder()
private let jsonDecoder = JSONDecoder()

#endif // DEBUG
