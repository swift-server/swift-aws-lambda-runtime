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

import Foundation // for JSON
import Logging
import NIO
import NIOHTTP1

/// An HTTP based client for AWS Runtime Engine. This encapsulates the RESTful methods exposed by the Runtime Engine:
/// * /runtime/invocation/next
/// * /runtime/invocation/response
/// * /runtime/invocation/error
/// * /runtime/init/error
internal extension Lambda {
    struct RuntimeClient {
        private let eventLoop: EventLoop
        private let allocator = ByteBufferAllocator()
        private let httpClient: HTTPClient

        init(eventLoop: EventLoop, configuration: Configuration.RuntimeEngine) {
            self.eventLoop = eventLoop
            self.httpClient = HTTPClient(eventLoop: eventLoop, configuration: configuration)
        }

        /// Requests work from the Runtime Engine.
        func requestWork(logger: Logger) -> EventLoopFuture<(Context, ByteBuffer)> {
            let url = Consts.invocationURLPrefix + Consts.requestWorkURLSuffix
            logger.debug("requesting work from lambda runtime engine using \(url)")
            return self.httpClient.get(url: url).flatMapThrowing { response in
                guard response.status == .ok else {
                    throw Errors.badStatusCode(response.status)
                }
                guard let payload = response.body else {
                    throw Errors.noBody
                }
                guard let context = Context(eventLoop: self.eventLoop, logger: logger, response: response) else {
                    throw Errors.noContext
                }
                return (context, payload)
            }.flatMapErrorThrowing { error in
                switch error {
                case HTTPClient.Errors.timeout:
                    throw Errors.upstreamError("timeout")
                case HTTPClient.Errors.connectionResetByPeer:
                    throw Errors.upstreamError("connectionResetByPeer")
                default:
                    throw error
                }
            }
        }

        /// Reports a result to the Runtime Engine.
        func reportResults(logger: Logger, context: Context, result: Result<ByteBuffer?, Error>) -> EventLoopFuture<Void> {
            var url = Consts.invocationURLPrefix + "/" + context.requestId
            var body: ByteBuffer?
            switch result {
            case .success(let data):
                url += Consts.postResponseURLSuffix
                body = data
            case .failure(let error):
                url += Consts.postErrorURLSuffix
                // TODO: make FunctionError a const
                let error = ErrorResponse(errorType: "FunctionError", errorMessage: "\(error)")
                switch error.toJson() {
                case .failure(let jsonError):
                    return self.eventLoop.makeFailedFuture(Errors.json(jsonError))
                case .success(let json):
                    body = self.allocator.buffer(capacity: json.utf8.count)
                    body!.writeString(json)
                }
            }
            logger.debug("reporting results to lambda runtime engine using \(url)")
            return self.httpClient.post(url: url, body: body ?? context.allocator.buffer(capacity: 0)).flatMapThrowing { response in
                guard response.status == .accepted else {
                    throw Errors.badStatusCode(response.status)
                }
                return ()
            }.flatMapErrorThrowing { error in
                switch error {
                case HTTPClient.Errors.timeout:
                    throw Errors.upstreamError("timeout")
                case HTTPClient.Errors.connectionResetByPeer:
                    throw Errors.upstreamError("connectionResetByPeer")
                default:
                    throw error
                }
            }
        }

        /// Reports an initialization error to the Runtime Engine.
        func reportInitializationError(logger: Logger, error: Error) -> EventLoopFuture<Void> {
            let url = Consts.postInitErrorURL
            let errorResponse = ErrorResponse(errorType: "InitializationError", errorMessage: "\(error)")
            var body: ByteBuffer
            switch errorResponse.toJson() {
            case .failure(let jsonError):
                return self.eventLoop.makeFailedFuture(Errors.json(jsonError))
            case .success(let json):
                body = self.allocator.buffer(capacity: json.utf8.count)
                body.writeString(json)
                logger.warning("reporting initialization error to lambda runtime engine using \(url)")
                return self.httpClient.post(url: url, body: body).flatMapThrowing { response in
                    guard response.status == .accepted else {
                        throw Errors.badStatusCode(response.status)
                    }
                    return ()
                }.flatMapErrorThrowing { error in
                    switch error {
                    case HTTPClient.Errors.timeout:
                        throw Errors.upstreamError("timeout")
                    case HTTPClient.Errors.connectionResetByPeer:
                        throw Errors.upstreamError("connectionResetByPeer")
                    default:
                        throw error
                    }
                }
            }
        }

        enum Errors: Error, Equatable {
            case badStatusCode(HTTPResponseStatus)
            case upstreamError(String)
            case noBody
            case noContext
            case json(JsonCodecError)
        }
    }
}

// FIXME: get rid of this. created to satisfy Equatable
internal struct JsonCodecError: Error, Equatable {
    let cause: Error
    init(_ cause: Error) {
        self.cause = cause
    }

    static func == (lhs: JsonCodecError, rhs: JsonCodecError) -> Bool {
        return lhs.cause.localizedDescription == rhs.cause.localizedDescription
    }
}

internal struct ErrorResponse: Codable {
    var errorType: String
    var errorMessage: String
}

private extension ErrorResponse {
    func toJson() -> Result<String, JsonCodecError> {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            return .success(String(data: data, encoding: .utf8) ?? "unknown error")
        } catch {
            return .failure(JsonCodecError(error))
        }
    }
}

private extension HTTPClient.Response {
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

private extension Lambda.Context {
    init?(eventLoop: EventLoop, logger: Logger, response: HTTPClient.Response) {
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
        self = Lambda.Context(requestId: requestId,
                              traceId: traceId,
                              invokedFunctionArn: invokedFunctionArn,
                              cognitoIdentity: cognitoIdentity,
                              clientContext: clientContext,
                              deadline: deadline,
                              eventLoop: eventLoop,
                              logger: logger)
    }
}
