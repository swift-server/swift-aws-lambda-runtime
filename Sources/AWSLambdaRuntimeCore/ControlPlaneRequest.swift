//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOHTTP1

enum ControlPlaneRequest: Hashable {
    case next
    case invocationResponse(String, ByteBuffer?)
    case invocationError(String, ErrorResponse)
    case initializationError(ErrorResponse)
}

enum ControlPlaneResponse: Hashable {
    case next(Invocation, ByteBuffer)
    case accepted
    case error(ErrorResponse)
}

struct Invocation: Hashable {
    let requestID: String
    let deadlineInMillisSinceEpoch: Int64
    let invokedFunctionARN: String
    let traceID: String
    let clientContext: String?
    let cognitoIdentity: String?

    init(headers: HTTPHeaders) throws {
        guard let requestID = headers.first(name: AmazonHeaders.requestID), !requestID.isEmpty else {
            throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.requestID)
        }

        guard let deadline = headers.first(name: AmazonHeaders.deadline),
              let unixTimeInMilliseconds = Int64(deadline)
        else {
            throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.deadline)
        }

        guard let invokedFunctionARN = headers.first(name: AmazonHeaders.invokedFunctionARN) else {
            throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.invokedFunctionARN)
        }

        self.requestID = requestID
        self.deadlineInMillisSinceEpoch = unixTimeInMilliseconds
        self.invokedFunctionARN = invokedFunctionARN
        self.traceID = headers.first(name: AmazonHeaders.traceID) ?? "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=0"
        self.clientContext = headers["Lambda-Runtime-Client-Context"].first
        self.cognitoIdentity = headers["Lambda-Runtime-Cognito-Identity"].first
    }
}

struct ErrorResponse: Hashable, Codable {
    var errorType: String
    var errorMessage: String
}

extension ErrorResponse {
    internal func toJSONBytes() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.append(UInt8(ascii: "{"))
        bytes.append(contentsOf: #""errorType":"#.utf8)
        self.errorType.encodeAsJSONString(into: &bytes)
        bytes.append(contentsOf: #","errorMessage":"#.utf8)
        self.errorMessage.encodeAsJSONString(into: &bytes)
        bytes.append(UInt8(ascii: "}"))
        return bytes
    }
}
