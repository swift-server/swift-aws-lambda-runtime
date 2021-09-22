//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore

extension EventLoopLambdaHandler where Event == String {
    /// Implementation of a `ByteBuffer` to `String` decoding
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> String {
        var buffer = buffer
        guard let string = buffer.readString(length: buffer.readableBytes) else {
            fatalError("buffer.readString(length: buffer.readableBytes) failed")
        }
        return string
    }
}

extension EventLoopLambdaHandler where Output == String {
    /// Implementation of `String` to `ByteBuffer` encoding
    @inlinable
    public func encode(allocator: ByteBufferAllocator, value: String) throws -> ByteBuffer? {
        // FIXME: reusable buffer
        var buffer = allocator.buffer(capacity: value.utf8.count)
        buffer.writeString(value)
        return buffer
    }
}
