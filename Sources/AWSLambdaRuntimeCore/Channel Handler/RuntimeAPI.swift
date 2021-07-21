//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import NIOHTTP1


/// AWS Lambda HTTP Headers, used to populate the `LambdaContext` object.
enum AmazonHeaders {
    static let requestID = "Lambda-Runtime-Aws-Request-Id"
    static let traceID = "Lambda-Runtime-Trace-Id"
    static let clientContext = "Lambda-Runtime-Client-Context"
    static let cognitoIdentity = "Lambda-Runtime-Cognito-Identity"
    static let deadline = "Lambda-Runtime-Deadline-Ms"
    static let invokedFunctionARN = "Lambda-Runtime-Invoked-Function-Arn"
}

struct ErrorResponse: Codable, Equatable {
    var errorType: String
    var errorMessage: String
}

extension ErrorResponse {
    func toJSONBytes() -> [UInt8] {
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

struct Invocation: Hashable {
    let requestID: String
    let deadlineInMillisSinceEpoch: Int64
    let invokedFunctionARN: String
    let traceID: String
    let clientContext: String?
    let cognitoIdentity: String?

    init(
        requestID: String,
        deadlineInMillisSinceEpoch: Int64,
        invokedFunctionARN: String,
        traceID: String,
        clientContext: String?,
        cognitoIdentity: String?
    ) {
        self.requestID = requestID
        self.deadlineInMillisSinceEpoch = deadlineInMillisSinceEpoch
        self.invokedFunctionARN = invokedFunctionARN
        self.traceID = traceID
        self.clientContext = clientContext
        self.cognitoIdentity = cognitoIdentity
    }
}

enum APIRequest: Equatable {
    case next
    case invocationResponse(String, ByteBuffer?)
    case invocationError(String, ErrorResponse)
    case initializationError(ErrorResponse)
}

enum APIResponse: Equatable {
    case next(Invocation, ByteBuffer)
    case accepted
    case error(ErrorResponse)
}
