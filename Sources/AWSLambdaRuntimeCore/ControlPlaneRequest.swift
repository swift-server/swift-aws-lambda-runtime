//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
    var requestID: String
    var deadlineInMillisSinceEpoch: Int64
    var invokedFunctionARN: String
    var traceID: String
    var clientContext: String?
    var cognitoIdentity: String?
    
    init(requestID: String,
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

        guard let traceID = headers.first(name: AmazonHeaders.traceID) else {
            throw Lambda.RuntimeError.invocationMissingHeader(AmazonHeaders.traceID)
        }

        self.init(
            requestID: requestID,
            deadlineInMillisSinceEpoch: unixTimeInMilliseconds,
            invokedFunctionARN: invokedFunctionARN,
            traceID: traceID,
            clientContext: headers["Lambda-Runtime-Client-Context"].first,
            cognitoIdentity: headers["Lambda-Runtime-Cognito-Identity"].first
        )
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
