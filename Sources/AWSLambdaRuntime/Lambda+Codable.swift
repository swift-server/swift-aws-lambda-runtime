//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import AWSLambdaRuntimeCore
import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import NIOCore
import NIOFoundationCompat

// MARK: - Codable support

/// Implementation of  a`ByteBuffer` to `Event` decoding
extension EventLoopLambdaHandler where Event: Decodable {
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> Event {
        try self.decoder.decode(Event.self, from: buffer)
    }
}

/// Implementation of  `Output` to `ByteBuffer` encoding
extension EventLoopLambdaHandler where Output: Encodable {
    @inlinable
    public func encode(allocator: ByteBufferAllocator, value: Output) throws -> ByteBuffer? {
        try self.encoder.encode(value, using: allocator)
    }
}

/// Default `ByteBuffer` to `Event` decoder using Foundation's JSONDecoder
/// Advanced users that want to inject their own codec can do it by overriding these functions.
extension EventLoopLambdaHandler where Event: Decodable {
    public var decoder: LambdaCodableDecoder {
        Lambda.defaultJSONDecoder
    }
}

/// Default `Output` to `ByteBuffer` encoder using Foundation's JSONEncoder
/// Advanced users that want to inject their own codec can do it by overriding these functions.
extension EventLoopLambdaHandler where Output: Encodable {
    public var encoder: LambdaCodableEncoder {
        Lambda.defaultJSONEncoder
    }
}

public protocol LambdaCodableDecoder {
    func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T
}

public protocol LambdaCodableEncoder {
    func encode<T: Encodable>(_ value: T, using allocator: ByteBufferAllocator) throws -> ByteBuffer
}

extension Lambda {
    fileprivate static let defaultJSONDecoder = JSONDecoder()
    fileprivate static let defaultJSONEncoder = JSONEncoder()
}

extension JSONDecoder: LambdaCodableDecoder {}

extension JSONEncoder: LambdaCodableEncoder {
    public func encode<T>(_ value: T, using allocator: ByteBufferAllocator) throws -> ByteBuffer where T: Encodable {
        // nio will resize the buffer if necessary
        var buffer = allocator.buffer(capacity: 1024)
        try self.encode(value, into: &buffer)
        return buffer
    }
}

extension JSONEncoder {
    /// Convenience method to allow encoding json directly into a `String`. It can be used to encode a payload into an `APIGateway.V2.Response`'s body.
    public func encodeAsString<T: Encodable>(_ value: T) throws -> String {
        try String(decoding: self.encode(value), as: Unicode.UTF8.self)
    }
}

extension JSONDecoder {
    /// Convenience method to allow decoding json directly from a `String`. It can be used to decode a payload from an `APIGateway.V2.Request`'s body.
    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        try self.decode(type, from: Data(string.utf8))
    }
}
