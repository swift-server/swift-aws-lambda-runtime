//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore

// MARK: - NonFactoryLambdaHandler String support

extension NonFactoryLambdaHandler where Event == String {
    /// Implementation of a `ByteBuffer` to `String` decoding.
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> Event {
        guard let value = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
            throw CodecError.invalidString
        }
        return value
    }
}

extension NonFactoryLambdaHandler where Output == String {
    /// Implementation of `String` to `ByteBuffer` encoding.
    @inlinable
    public func encode(value: Output, into buffer: inout ByteBuffer) throws {
        buffer.writeString(value)
    }
}

// MARK: - EventLoopLambdaHandler String support

extension EventLoopLambdaHandler where Event == String {
    /// Implementation of `String` to `ByteBuffer` encoding.
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> Event {
        guard let value = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
            throw CodecError.invalidString
        }
        return value
    }
}

extension EventLoopLambdaHandler where Output == String {
    /// Implementation of a `ByteBuffer` to `String` decoding.
    @inlinable
    public func encode(value: Output, into buffer: inout ByteBuffer) throws {
        buffer.writeString(value)
    }
}
