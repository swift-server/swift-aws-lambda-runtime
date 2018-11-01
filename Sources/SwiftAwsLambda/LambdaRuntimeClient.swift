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

internal class LambdaRuntimeClient {
    private let baseUrl: String
    private let httpClient: HTTPClient
    private let eventLoop: EventLoop
    private let allocator: ByteBufferAllocator

    init(eventLoop: EventLoop) {
        baseUrl = getRuntimeEndpoint()
        httpClient = HTTPClient(eventLoop: eventLoop)
        self.eventLoop = eventLoop
        allocator = ByteBufferAllocator()
    }

    func requestWork() -> EventLoopFuture<RequestWorkResult> {
        let url = baseUrl + Consts.InvokationUrlPrefix + Consts.RequestWorkUrlSuffix
        print("requesting work from lambda runtime engine using \(url)")
        return httpClient.get(url: url).map { response in
            if .ok != response.status {
                return .failure(.badStatusCode)
            }
            guard let payload = response.readWholeBody() else {
                return .failure(.noBody)
            }
            guard let context = LambdaContext.from(response) else {
                return .failure(.noContext)
            }
            return .success(context: context, payload: payload)
        }
    }

    func reportResults(context: LambdaContext, result: LambdaResult) -> EventLoopFuture<PostResultsResult> {
        var url = baseUrl + Consts.InvokationUrlPrefix + "/" + context.requestId
        var body: ByteBuffer
        switch result {
        case let .success(data):
            url += Consts.PostResponseUrlSuffix
            body = allocator.buffer(capacity: data.count)
            body.write(bytes: data)
        case let .failure(error):
            url += Consts.PostErrorUrlSuffix
            // TODO: make FunctionError a const
            // FIXME: error
            let error = ErrorResponse(errorType: "FunctionError", errorMessage: "\(error)")
            guard let json = error.toJson() else {
                return eventLoop.newSucceededFuture(result: .failure(.json))
            }
            body = allocator.buffer(capacity: json.utf8.count)
            body.write(string: json)
        }

        print("reporting results to lambda runtime engine using \(url)")
        return httpClient.post(url: url, body: body).map { response in
            .accepted != response.status ? .failure(.badStatusCode) : .success()
        }
    }
}

internal enum RequestWorkResult {
    case success(context: LambdaContext, payload: [UInt8])
    case failure(LambdaRuntimeClientError)
}

internal enum PostResultsResult {
    case success()
    case failure(LambdaRuntimeClientError)
}

internal enum LambdaRuntimeClientError: Error {
    case badStatusCode
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
    func getHeaderValue(_ name: String) -> String? {
        return headers[name][safe: 0]
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
    static func from(_ response: HTTPResponse) -> LambdaContext? {
        guard let requestId = response.getHeaderValue(AmazonHeaders.RequestId) else {
            return nil
        }
        if requestId.isEmpty {
            return nil
        }
        let traceId = response.getHeaderValue(AmazonHeaders.TraceId)
        let invokedFunctionArn = response.getHeaderValue(AmazonHeaders.InvokedFunctionArn)
        let cognitoIdentity = response.getHeaderValue(AmazonHeaders.CognitoIdentity)
        let clientContext = response.getHeaderValue(AmazonHeaders.ClientContext)
        let deadlineNs = response.getHeaderValue(AmazonHeaders.DeadlineNs)
        return LambdaContext(requestId: requestId,
                             traceId: traceId,
                             invokedFunctionArn: invokedFunctionArn,
                             cognitoIdentity: cognitoIdentity,
                             clientContext: clientContext,
                             deadlineNs: deadlineNs)
    }
}

private func getRuntimeEndpoint() -> String {
    if let hostPort = Environment.getString(Consts.HostPortEnvVariableName) {
        return "http://\(hostPort)"
    } else {
        return "http://\(Defaults.Host):\(Defaults.Port)"
    }
}
