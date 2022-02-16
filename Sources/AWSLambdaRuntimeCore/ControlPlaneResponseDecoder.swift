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

import NIOCore

struct ControlPlaneResponseDecoder: NIOSingleStepByteToMessageDecoder {
    typealias InboundOut = ControlPlaneResponse

    private enum State {
        case waitingForNewResponse
        case parsingHead(PartialHead)
        case waitingForBody(PartialHead)
        case receivingBody(PartialHead, ByteBuffer)
    }

    private var state: State

    init() {
        self.state = .waitingForNewResponse
    }

    mutating func decode(buffer: inout ByteBuffer) throws -> ControlPlaneResponse? {
        switch self.state {
        case .waitingForNewResponse:
            guard case .decoded(let head) = try self.decodeResponseHead(from: &buffer) else {
                return nil
            }

            guard case .decoded(let body) = try self.decodeBody(from: &buffer) else {
                return nil
            }

            return try self.decodeResponse(head: head, body: body)

        case .parsingHead:
            guard case .decoded(let head) = try self.decodeHeaderLines(from: &buffer) else {
                return nil
            }

            guard case .decoded(let body) = try self.decodeBody(from: &buffer) else {
                return nil
            }

            return try self.decodeResponse(head: head, body: body)

        case .waitingForBody(let head), .receivingBody(let head, _):
            guard case .decoded(let body) = try self.decodeBody(from: &buffer) else {
                return nil
            }

            return try self.decodeResponse(head: head, body: body)
        }
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> ControlPlaneResponse? {
        try self.decode(buffer: &buffer)
    }

    // MARK: - Private Methods -

    private enum DecodeResult<T> {
        case needMoreData
        case decoded(T)
    }

    private mutating func decodeResponseHead(from buffer: inout ByteBuffer) throws -> DecodeResult<PartialHead> {
        guard case .decoded = try self.decodeResponseStatusLine(from: &buffer) else {
            return .needMoreData
        }

        return try self.decodeHeaderLines(from: &buffer)
    }

    private mutating func decodeResponseStatusLine(from buffer: inout ByteBuffer) throws -> DecodeResult<Int> {
        guard case .waitingForNewResponse = self.state else {
            preconditionFailure("Invalid state: \(self.state)")
        }

        guard case .decoded(var lineBuffer) = try self.decodeCRLFTerminatedLine(from: &buffer) else {
            return .needMoreData
        }

        let statusCode = try self.decodeStatusLine(from: &lineBuffer)
        self.state = .parsingHead(.init(statusCode: statusCode))
        return .decoded(statusCode)
    }

    private mutating func decodeHeaderLines(from buffer: inout ByteBuffer) throws -> DecodeResult<PartialHead> {
        guard case .parsingHead(var head) = self.state else {
            preconditionFailure("Invalid state: \(self.state)")
        }

        while true {
            guard case .decoded(var nextLine) = try self.decodeCRLFTerminatedLine(from: &buffer) else {
                self.state = .parsingHead(head)
                return .needMoreData
            }

            switch try self.decodeHeaderLine(from: &nextLine) {
            case .headerEnd:
                self.state = .waitingForBody(head)
                return .decoded(head)

            case .contentLength(let length):
                head.contentLength = length

            case .contentType:
                break // switch

            case .requestID(let requestID):
                head.requestID = requestID

            case .traceID(let traceID):
                head.traceID = traceID

            case .functionARN(let arn):
                head.invokedFunctionARN = arn

            case .cognitoIdentity(let cognitoIdentity):
                head.cognitoIdentity = cognitoIdentity

            case .deadlineMS(let deadline):
                head.deadlineInMillisSinceEpoch = deadline

            case .ignore:
                break // switch
            }
        }
    }

    enum BodyEncoding {
        case chunked
        case plain(length: Int)
        case none
    }

    static let sixMegaBytes = 6 * 1024 * 1024

    private mutating func decodeBody(from buffer: inout ByteBuffer) throws -> DecodeResult<ByteBuffer?> {
        switch self.state {
        case .waitingForBody(let partialHead):
            switch partialHead.contentLength {
            case .none:
                return .decoded(nil)
            case .some(let length):
                precondition(length <= Self.sixMegaBytes)
                if let slice = buffer.readSlice(length: Int(length)) {
                    self.state = .waitingForNewResponse
                    return .decoded(slice)
                }
                return .needMoreData
            }

        case .waitingForNewResponse, .parsingHead, .receivingBody:
            preconditionFailure("Invalid state: \(self.state)")
        }
    }

    private mutating func decodeResponse(head: PartialHead, body: ByteBuffer?) throws -> ControlPlaneResponse {
        switch head.statusCode {
        case 200:
            guard let body = body else {
                throw LambdaRuntimeError.invocationMissingPayload
            }
            return .next(try Invocation(head: head), body)

        case 202:
            return .accepted

        case 400, 403:
            throw LambdaRuntimeError.controlPlaneErrorResponse(<#T##response: ErrorResponse##ErrorResponse#>)

        default:
            throw LambdaRuntimeError.unexpectedStatusCode
        }
    }

    mutating func decodeStatusLine(from buffer: inout ByteBuffer) throws -> Int {
        guard buffer.readableBytes >= 11 else {
            throw LambdaRuntimeError.responseHeadInvalidStatusLine
        }

        guard buffer.readString("HTTP/1.1 ") else {
            throw LambdaRuntimeError.responseHeadInvalidStatusLine
        }

        let statusAsString = buffer.readString(length: 3)!
        guard let status = Int(statusAsString) else {
            throw LambdaRuntimeError.responseHeadInvalidStatusLine
        }

        return status
    }

    private mutating func decodeCRLFTerminatedLine(from buffer: inout ByteBuffer) throws -> DecodeResult<ByteBuffer> {
        guard let crIndex = buffer.readableBytesView.firstIndex(of: UInt8(ascii: "\r")) else {
            if buffer.readableBytes > 256 {
                throw LambdaRuntimeError.responseHeadMoreThan256BytesBeforeCRLF
            }
            return .needMoreData
        }
        let lfIndex = buffer.readableBytesView.index(after: crIndex)
        guard lfIndex < buffer.readableBytesView.endIndex else {
            // the buffer is split exactly after the \r and \n. Let's wait for more data
            return .needMoreData
        }

        guard buffer.readableBytesView[lfIndex] == UInt8(ascii: "\n") else {
            throw LambdaRuntimeError.responseHeadInvalidHeader
        }

        let slice = buffer.readSlice(length: crIndex - buffer.readerIndex)!
        buffer.moveReaderIndex(forwardBy: 2) // move over \r\n
        return .decoded(slice)
    }

    private enum HeaderLineContent: Equatable {
        case traceID(String)
        case contentType
        case contentLength(UInt64)
        case cognitoIdentity(String)
        case deadlineMS(UInt64)
        case functionARN(String)
        case requestID(LambdaRequestID)

        case ignore
        case headerEnd
    }

    private mutating func decodeHeaderLine(from buffer: inout ByteBuffer) throws -> HeaderLineContent {
        guard let colonIndex = buffer.readableBytesView.firstIndex(of: UInt8(ascii: ":")) else {
            if buffer.readableBytes == 0 {
                return .headerEnd
            }
            throw LambdaRuntimeError.responseHeadHeaderMissingColon
        }

        // based on colonIndex we can already make some good guesses...
        //  4: Date
        // 12: Content-Type
        // 14: Content-Length
        // 17: Transfer-Encoding
        // 23: Lambda-Runtime-Trace-Id
        // 26: Lambda-Runtime-Deadline-Ms
        // 29: Lambda-Runtime-Aws-Request-Id
        //     Lambda-Runtime-Client-Context
        // 31: Lambda-Runtime-Cognito-Identity
        // 35: Lambda-Runtime-Invoked-Function-Arn

        switch colonIndex {
        case 4:
            if buffer.readHeaderName("date") {
                return .ignore
            }

        case 12:
            if buffer.readHeaderName("content-type") {
                return .ignore
            }

        case 14:
            if buffer.readHeaderName("content-length") {
                buffer.moveReaderIndex(forwardBy: 1) // move forward for colon
                try self.decodeOptionalWhiteSpaceBeforeFieldValue(from: &buffer)
                guard let length = buffer.readUInt64FromHeader() else {
                    throw LambdaRuntimeError.responseHeadInvalidContentLengthValue
                }
                guard length < 6 * 1024 * 1024 else {
                    // A lambda must not have a body larger than 6MB:
                    //     https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
                    throw LambdaRuntimeError.responseHeadInvalidContentLengthValue
                }

                return .contentLength(length)
            }

        case 17:
            if buffer.readHeaderName("transfer-encoding") {
                throw LambdaRuntimeError.responseHeadTransferEncodingChunkedNotSupported
            }

        case 23:
            if buffer.readHeaderName("lambda-runtime-trace-id") {
                buffer.moveReaderIndex(forwardBy: 1)
                guard let string = try self.decodeHeaderValue(from: &buffer) else {
                    throw LambdaRuntimeError.responseHeadInvalidTraceIDValue
                }
                return .traceID(string)
            }

        case 26:
            if buffer.readHeaderName("lambda-runtime-deadline-ms") {
                buffer.moveReaderIndex(forwardBy: 1) // move forward for colon
                try self.decodeOptionalWhiteSpaceBeforeFieldValue(from: &buffer)
                guard let deadline = buffer.readUInt64FromHeader() else {
                    throw LambdaRuntimeError.responseHeadInvalidDeadlineValue
                }
                return .deadlineMS(deadline)
            }

        case 29:
            if buffer.readHeaderName("lambda-runtime-aws-request-id") {
                buffer.moveReaderIndex(forwardBy: 1) // move forward for colon
                try self.decodeOptionalWhiteSpaceBeforeFieldValue(from: &buffer)
                guard let requestID = buffer.readRequestID() else {
                    throw LambdaRuntimeError.responseHeadInvalidRequestIDValue
                }
                return .requestID(requestID)
            }
            if buffer.readHeaderName("lambda-runtime-client-context") {
                return .ignore
            }

        case 31:
            if buffer.readHeaderName("lambda-runtime-cognito-identity") {
                return .ignore
            }

        case 35:
            if buffer.readHeaderName("lambda-runtime-invoked-function-arn") {
                buffer.moveReaderIndex(forwardBy: 1)
                guard let string = try self.decodeHeaderValue(from: &buffer) else {
                    throw LambdaRuntimeError.responseHeadInvalidTraceIDValue
                }
                return .functionARN(string)
            }

        default:
            // Ensure we received a valid http header:
            break // fallthrough
        }

        // We received a header we didn't expect, let's ensure it is valid.
        let satisfy = buffer.readableBytesView[0 ..< colonIndex].allSatisfy { char -> Bool in
            switch char {
            case UInt8(ascii: "a") ... UInt8(ascii: "z"),
                 UInt8(ascii: "A") ... UInt8(ascii: "Z"),
                 UInt8(ascii: "0") ... UInt8(ascii: "9"),
                 UInt8(ascii: "!"),
                 UInt8(ascii: "#"),
                 UInt8(ascii: "$"),
                 UInt8(ascii: "%"),
                 UInt8(ascii: "&"),
                 UInt8(ascii: "'"),
                 UInt8(ascii: "*"),
                 UInt8(ascii: "+"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "."),
                 UInt8(ascii: "^"),
                 UInt8(ascii: "_"),
                 UInt8(ascii: "`"),
                 UInt8(ascii: "|"),
                 UInt8(ascii: "~"):
                return true
            default:
                return false
            }
        }

        guard satisfy else {
            throw LambdaRuntimeError.responseHeadHeaderInvalidCharacter
        }

        return .ignore
    }

    @discardableResult
    mutating func decodeOptionalWhiteSpaceBeforeFieldValue(from buffer: inout ByteBuffer) throws -> Int {
        let startIndex = buffer.readerIndex
        guard let index = buffer.readableBytesView.firstIndex(where: { $0 != UInt8(ascii: " ") && $0 != UInt8(ascii: "\t") }) else {
            throw LambdaRuntimeError.responseHeadHeaderMissingFieldValue
        }
        buffer.moveReaderIndex(to: index)
        return index - startIndex
    }

    private func decodeHeaderValue(from buffer: inout ByteBuffer) throws -> String? {
        func isNotOptionalWhiteSpace(_ val: UInt8) -> Bool {
            val != UInt8(ascii: " ") && val != UInt8(ascii: "\t")
        }

        guard let firstCharacterIndex = buffer.readableBytesView.firstIndex(where: isNotOptionalWhiteSpace),
              let lastCharacterIndex = buffer.readableBytesView.lastIndex(where: isNotOptionalWhiteSpace)
        else {
            throw LambdaRuntimeError.responseHeadHeaderMissingFieldValue
        }

        let string = buffer.getString(at: firstCharacterIndex, length: lastCharacterIndex + 1 - firstCharacterIndex)
        buffer.moveReaderIndex(to: buffer.writerIndex)
        return string
    }
}

extension ControlPlaneResponseDecoder {
    fileprivate struct PartialHead {
        var statusCode: Int
        var contentLength: UInt64?

        var requestID: LambdaRequestID?
        var deadlineInMillisSinceEpoch: UInt64?
        var invokedFunctionARN: String?
        var traceID: String?
        var clientContext: String?
        var cognitoIdentity: String?

        init(statusCode: Int) {
            self.statusCode = statusCode
            self.contentLength = nil

            self.requestID = nil
            self.deadlineInMillisSinceEpoch = nil
            self.invokedFunctionARN = nil
            self.traceID = nil
            self.clientContext = nil
            self.cognitoIdentity = nil
        }
    }
}

extension ByteBuffer {
    fileprivate mutating func readString(_ string: String) -> Bool {
        let result = self.withUnsafeReadableBytes { inputBuffer in
            string.utf8.withContiguousStorageIfAvailable { validateBuffer -> Bool in
                assert(inputBuffer.count >= validateBuffer.count)

                for idx in 0 ..< validateBuffer.count {
                    if inputBuffer[idx] != validateBuffer[idx] {
                        return false
                    }
                }
                return true
            }
        }!

        if result {
            self.moveReaderIndex(forwardBy: string.utf8.count)
            return true
        }

        return false
    }

    fileprivate mutating func readHeaderName(_ name: String) -> Bool {
        let result = self.withUnsafeReadableBytes { inputBuffer in
            name.utf8.withContiguousStorageIfAvailable { nameBuffer -> Bool in
                assert(inputBuffer.count >= nameBuffer.count)

                for idx in 0 ..< nameBuffer.count {
                    // let's hope this gets vectorised ;)
                    if inputBuffer[idx] & 0xDF != nameBuffer[idx] & 0xDF {
                        return false
                    }
                }
                return true
            }
        }!

        if result {
            self.moveReaderIndex(forwardBy: name.utf8.count)
            return true
        }

        return false
    }

    // We must ensure that we can multiply our current value by ten and add at least 9.
    private static let maxIncreasableUInt64 = UInt64.max / 100

    mutating func readUInt64FromHeader() -> UInt64? {
        guard let ascii = self.readInteger(as: UInt8.self), UInt8(ascii: "0") <= ascii && ascii <= UInt8(ascii: "9") else {
            return nil
        }
        var value = UInt64(ascii - UInt8(ascii: "0"))
        loop: while let ascii = self.readInteger(as: UInt8.self) {
            switch ascii {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                if value > Self.maxIncreasableUInt64 {
                    return nil
                }
                value = value * 10
                value += UInt64(ascii - UInt8(ascii: "0"))

            case UInt8(ascii: " "), UInt8(ascii: "\t"):
                // verify that all following characters are also whitespace
                guard self.readableBytesView.allSatisfy({ $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") }) else {
                    return nil
                }
                return value

            default:
                return nil
            }
        }

        return value
    }
}

extension Invocation {
    fileprivate init(head: ControlPlaneResponseDecoder.PartialHead) throws {
        guard let requestID = head.requestID else {
            throw LambdaRuntimeError.invocationHeadMissingRequestID
        }

        guard let deadlineInMillisSinceEpoch = head.deadlineInMillisSinceEpoch else {
            throw LambdaRuntimeError.invocationHeadMissingDeadlineInMillisSinceEpoch
        }

        guard let invokedFunctionARN = head.invokedFunctionARN else {
            throw LambdaRuntimeError.invocationHeadMissingFunctionARN
        }

        guard let traceID = head.traceID else {
            throw LambdaRuntimeError.invocationHeadMissingTraceID
        }

        self = Invocation(
            requestID: requestID.lowercased,
            deadlineInMillisSinceEpoch: deadlineInMillisSinceEpoch,
            invokedFunctionARN: invokedFunctionARN,
            traceID: traceID,
            clientContext: head.clientContext,
            cognitoIdentity: head.cognitoIdentity
        )
    }
}
