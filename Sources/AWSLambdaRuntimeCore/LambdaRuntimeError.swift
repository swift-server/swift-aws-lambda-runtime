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
        case statusCodeBadRequest
        case statusCodeForbidden
        case containerError

        case responseHeadInvalidStatusLine
        case responseHeadTransferEncodingChunkedNotSupported
        case responseHeadMissingContentLengthOrTransferEncodingChunked
        case responseHeadMoreThan256BytesBeforeCRLF
        case responseHeadHeaderInvalidCharacter
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

        case invocationMissingPayload
        case controlPlaneErrorResponse(ErrorResponse)
    }

    private let base: Base

    private init(_ base: Base) {
        self.base = base
    }

    static let unsolicitedResponse = LambdaRuntimeError(.unsolicitedResponse)
    static let unexpectedStatusCode = LambdaRuntimeError(.unexpectedStatusCode)
    static let statusCodeBadRequest = LambdaRuntimeError(.statusCodeBadRequest)
    static let statusCodeForbidden = LambdaRuntimeError(.statusCodeForbidden)
    static let containerError = LambdaRuntimeError(.containerError)

    static let responseHeadInvalidStatusLine = LambdaRuntimeError(.responseHeadInvalidStatusLine)
    static let responseHeadTransferEncodingChunkedNotSupported =
        LambdaRuntimeError(.responseHeadTransferEncodingChunkedNotSupported)
    static let responseHeadMissingContentLengthOrTransferEncodingChunked =
        LambdaRuntimeError(.responseHeadMissingContentLengthOrTransferEncodingChunked)
    static let responseHeadMoreThan256BytesBeforeCRLF = LambdaRuntimeError(.responseHeadMoreThan256BytesBeforeCRLF)
    static let responseHeadHeaderInvalidCharacter = LambdaRuntimeError(.responseHeadHeaderInvalidCharacter)
    static let responseHeadHeaderMissingColon = LambdaRuntimeError(.responseHeadHeaderMissingColon)
    static let responseHeadHeaderMissingFieldValue = LambdaRuntimeError(.responseHeadHeaderMissingFieldValue)
    static let responseHeadInvalidHeader = LambdaRuntimeError(.responseHeadInvalidHeader)
    static let responseHeadInvalidContentLengthValue = LambdaRuntimeError(.responseHeadInvalidContentLengthValue)
    static let responseHeadInvalidRequestIDValue = LambdaRuntimeError(.responseHeadInvalidRequestIDValue)
    static let responseHeadInvalidTraceIDValue = LambdaRuntimeError(.responseHeadInvalidTraceIDValue)
    static let responseHeadInvalidDeadlineValue = LambdaRuntimeError(.responseHeadInvalidDeadlineValue)

    static let invocationHeadMissingRequestID = LambdaRuntimeError(.invocationHeadMissingRequestID)
    static let invocationHeadMissingDeadlineInMillisSinceEpoch = LambdaRuntimeError(.invocationHeadMissingDeadlineInMillisSinceEpoch)
    static let invocationHeadMissingFunctionARN = LambdaRuntimeError(.invocationHeadMissingFunctionARN)
    static let invocationHeadMissingTraceID = LambdaRuntimeError(.invocationHeadMissingTraceID)

    static let invocationMissingPayload = LambdaRuntimeError(.invocationMissingPayload)

    static func controlPlaneErrorResponse(_ response: ErrorResponse) -> Self {
        LambdaRuntimeError(.controlPlaneErrorResponse(response))
    }
}
