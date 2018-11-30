//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIO
import NIOHTTP1

/// An HTTP based client for AWS Runtime Engine. This encapsulates the RESTful methods exposed by the Runtime Engine:
/// * /runtime/invocation/next
/// * /runtime/invocation/response
/// * /runtime/invocation/error
internal class LambdaRuntimeClient {
    private let baseUrl: String
    private let httpClient: HTTPClient
    private let eventLoop: EventLoop
    private let allocator: ByteBufferAllocator

    init(eventLoop: EventLoop) {
        self.baseUrl = getRuntimeEndpoint()
        self.httpClient = HTTPClient(eventLoop: eventLoop)
        self.eventLoop = eventLoop
        self.allocator = ByteBufferAllocator()
    }

    func requestWork() -> EventLoopFuture<RequestWorkResult> {
        let url = baseUrl + Consts.invokationURLPrefix + Consts.requestWorkURLSuffix
        print("requesting work from lambda runtime engine using \(url)")
        return self.httpClient.get(url: url).map { response in
            if .ok != response.status {
                return .failure(.badStatusCode(response.status))
            }
            guard let payload = response.readWholeBody() else {
                return .failure(.noBody)
            }
            guard let context = LambdaContext(response: response) else {
                return .failure(.noContext)
            }
            return .success((context, payload))
        }
    }

    func reportResults(context: LambdaContext, result: LambdaResult) -> EventLoopFuture<PostResultsResult> {
        var url = baseUrl + Consts.invokationURLPrefix + "/" + context.requestId
        var body: ByteBuffer
        switch result {
        case let .success(data):
            url += Consts.postResponseURLSuffix
            body = self.allocator.buffer(capacity: data.count)
            body.write(bytes: data)
        case let .failure(error):
            url += Consts.postErrorURLSuffix
            // TODO: make FunctionError a const
            let error = ErrorResponse(errorType: "FunctionError", errorMessage: "\(error)")
            guard let json = error.toJson() else {
                return self.eventLoop.newSucceededFuture(result: .failure(.json))
            }
            body = self.allocator.buffer(capacity: json.utf8.count)
            body.write(string: json)
        }

        print("reporting results to lambda runtime engine using \(url)")
        return self.httpClient.post(url: url, body: body).map { response in
            .accepted != response.status ? .failure(.badStatusCode(response.status)) : .success(())
        }
    }
}

internal typealias RequestWorkResult = Result<(LambdaContext, [UInt8]), LambdaRuntimeClientError>
internal typealias PostResultsResult = Result<(), LambdaRuntimeClientError>

internal enum LambdaRuntimeClientError: Error {
    case badStatusCode(HTTPResponseStatus)
    case noBody
    case noContext
    case json
}

internal struct ErrorResponse: Codable {
    var errorType: String
    var errorMessage: String
}

private extension ErrorResponse {
    func toJson() -> String? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

private extension HTTPResponse {
    func headerValue(_ name: String) -> String? {
        return headers[name].first
    }

    func readWholeBody() -> [UInt8]? {
        guard var buffer = self.body else {
            return nil
        }
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
            return nil
        }
        return bytes
    }
}

private extension LambdaContext {
    init?(response: HTTPResponse) {
        guard let requestId = response.headerValue(AmazonHeaders.requestID) else {
            return nil
        }
        if requestId.isEmpty {
            return nil
        }
        let traceId = response.headerValue(AmazonHeaders.traceID)
        let invokedFunctionArn = response.headerValue(AmazonHeaders.invokedFunctionARN)
        let cognitoIdentity = response.headerValue(AmazonHeaders.cognitoIdentity)
        let clientContext = response.headerValue(AmazonHeaders.clientContext)
        let deadline = response.headerValue(AmazonHeaders.deadline)
        self = LambdaContext(requestId: requestId,
                             traceId: traceId,
                             invokedFunctionArn: invokedFunctionArn,
                             cognitoIdentity: cognitoIdentity,
                             clientContext: clientContext,
                             deadline: deadline)
    }
}

private func getRuntimeEndpoint() -> String {
    if let hostPort = Environment.string(Consts.hostPortEnvVariableName) {
        return "http://\(hostPort)"
    } else {
        return "http://\(Defaults.host):\(Defaults.port)"
    }
}
