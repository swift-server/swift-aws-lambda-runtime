//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

struct LambdaRuntimeError: Error, Hashable {
    enum Base: Hashable {
        case unsolicitedResponse
        case unexpectedStatusCode
        
        case responseHeadInvalidStatusLine
        case responseHeadMissingContentLengthOrTransferEncodingChunked
        case responseHeadMoreThan256BytesBeforeCRLF
        case responseHeadHeaderMissingColon
        case responseHeadHeaderMissingFieldValue
        case responseHeadInvalidHeader
        case responseHeadInvalidContentLengthValue
        case responseHeadInvalidRequestIDValue
        case responseHeadInvalidTraceIDValue
        case responseHeadInvalidDeadlineValue
        
        case invocationHeadMissingRequestID
        case invocationHeadMissingDeadlineInMillisSinceEpoch
        case invocationHeadMissingFunctionARN
        case invocationHeadMissingTraceID
        
        case controlPlaneErrorResponse(ErrorResponse)
    }
    
    private let base: Base
    
    private init(_ base: Base) {
        self.base = base
    }
    
    static var unsolicitedResponse = LambdaRuntimeError(.unsolicitedResponse)
    static var unexpectedStatusCode = LambdaRuntimeError(.unexpectedStatusCode)
    static var responseHeadInvalidStatusLine = LambdaRuntimeError(.responseHeadInvalidStatusLine)
    static var responseHeadMissingContentLengthOrTransferEncodingChunked =
        LambdaRuntimeError(.responseHeadMissingContentLengthOrTransferEncodingChunked)
    static var responseHeadMoreThan256BytesBeforeCRLF = LambdaRuntimeError(.responseHeadMoreThan256BytesBeforeCRLF)
    static var responseHeadHeaderMissingColon = LambdaRuntimeError(.responseHeadHeaderMissingColon)
    static var responseHeadHeaderMissingFieldValue = LambdaRuntimeError(.responseHeadHeaderMissingFieldValue)
    static var responseHeadInvalidHeader = LambdaRuntimeError(.responseHeadInvalidHeader)
    static var responseHeadInvalidContentLengthValue = LambdaRuntimeError(.responseHeadInvalidContentLengthValue)
    static var responseHeadInvalidRequestIDValue = LambdaRuntimeError(.responseHeadInvalidRequestIDValue)
    static var responseHeadInvalidTraceIDValue = LambdaRuntimeError(.responseHeadInvalidTraceIDValue)
    static var responseHeadInvalidDeadlineValue = LambdaRuntimeError(.responseHeadInvalidDeadlineValue)
    static var invocationHeadMissingRequestID = LambdaRuntimeError(.invocationHeadMissingRequestID)
    static var invocationHeadMissingDeadlineInMillisSinceEpoch = LambdaRuntimeError(.invocationHeadMissingDeadlineInMillisSinceEpoch)
    static var invocationHeadMissingFunctionARN = LambdaRuntimeError(.invocationHeadMissingFunctionARN)
    static var invocationHeadMissingTraceID = LambdaRuntimeError(.invocationHeadMissingTraceID)
    
    static func controlPlaneErrorResponse(_ response: ErrorResponse) -> Self {
        LambdaRuntimeError(.controlPlaneErrorResponse(response))
    }
}
