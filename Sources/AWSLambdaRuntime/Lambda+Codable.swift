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

@_exported import AWSLambdaRuntimeCore
import NIOCore
import NIOFoundationCompat

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
#endif

// MARK: - SimpleLambdaHandler Codable support

/// Implementation of `ByteBuffer` to `Event` decoding.
extension SimpleLambdaHandler where Event: Decodable {
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> Event {
        try self.decoder.decode(Event.self, from: buffer)
    }
}

/// Implementation of `Output` to `ByteBuffer` encoding.
extension SimpleLambdaHandler where Output: Encodable {
    @inlinable
    public func encode(value: Output, into buffer: inout ByteBuffer) throws {
        try self.encoder.encode(value, into: &buffer)
    }
}

/// Default `ByteBuffer` to `Event` decoder using Foundation's `JSONDecoder`.
/// Advanced users who want to inject their own codec can do it by overriding these functions.
extension SimpleLambdaHandler where Event: Decodable {
    public var decoder: LambdaCodableDecoder {
        Lambda.defaultJSONDecoder
    }
}

/// Default `Output` to `ByteBuffer` encoder using Foundation's `JSONEncoder`.
/// Advanced users who want to inject their own codec can do it by overriding these functions.
extension SimpleLambdaHandler where Output: Encodable {
    public var encoder: LambdaCodableEncoder {
        Lambda.defaultJSONEncoder
    }
}

// MARK: - LambdaHandler Codable support

/// Implementation of `ByteBuffer` to `Event` decoding.
extension LambdaHandler where Event: Decodable {
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> Event {
        try self.decoder.decode(Event.self, from: buffer)
    }
}

/// Implementation of `Output` to `ByteBuffer` encoding.
extension LambdaHandler where Output: Encodable {
    @inlinable
    public func encode(value: Output, into buffer: inout ByteBuffer) throws {
        try self.encoder.encode(value, into: &buffer)
    }
}

/// Default `ByteBuffer` to `Event` decoder using Foundation's `JSONDecoder`.
/// Advanced users who want to inject their own codec can do it by overriding these functions.
extension LambdaHandler where Event: Decodable {
    public var decoder: LambdaCodableDecoder {
        Lambda.defaultJSONDecoder
    }
}

/// Default `Output` to `ByteBuffer` encoder using Foundation's `JSONEncoder`.
/// Advanced users who want to inject their own codec can do it by overriding these functions.
extension LambdaHandler where Output: Encodable {
    public var encoder: LambdaCodableEncoder {
        Lambda.defaultJSONEncoder
    }
}

// MARK: - EventLoopLambdaHandler Codable support

/// Implementation of `ByteBuffer` to `Event` decoding.
extension EventLoopLambdaHandler where Event: Decodable {
    @inlinable
    public func decode(buffer: ByteBuffer) throws -> Event {
        try self.decoder.decode(Event.self, from: buffer)
    }
}

/// Implementation of `Output` to `ByteBuffer` encoding.
extension EventLoopLambdaHandler where Output: Encodable {
    @inlinable
    public func encode(value: Output, into buffer: inout ByteBuffer) throws {
        try self.encoder.encode(value, into: &buffer)
    }
}

/// Default `ByteBuffer` to `Event` decoder using Foundation's `JSONDecoder`.
/// Advanced users that want to inject their own codec can do it by overriding these functions.
extension EventLoopLambdaHandler where Event: Decodable {
    public var decoder: LambdaCodableDecoder {
        Lambda.defaultJSONDecoder
    }
}

/// Default `Output` to `ByteBuffer` encoder using Foundation's `JSONEncoder`.
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
    func encode<T: Encodable>(_ value: T, into buffer: inout ByteBuffer) throws
}

extension Lambda {
    fileprivate static let defaultJSONDecoder = JSONDecoder()
    fileprivate static let defaultJSONEncoder = JSONEncoder()
}

extension JSONDecoder: LambdaCodableDecoder {}

extension JSONEncoder: LambdaCodableEncoder {}

extension JSONDecoder: AWSLambdaRuntimeCore.LambdaEventDecoder {}

@usableFromInline
package struct LambdaJSONOutputEncoder<Output: Encodable>: LambdaOutputEncoder {
    @usableFromInline let jsonEncoder: JSONEncoder

    @inlinable
    package init(_ jsonEncoder: JSONEncoder) {
        self.jsonEncoder = jsonEncoder
    }

    @inlinable
    package func encode(_ value: Output, into buffer: inout ByteBuffer) throws {
        try self.jsonEncoder.encode(value, into: &buffer)
    }
}

extension LambdaCodableAdapter {
    /// Initializes an instance given an encoder, decoder, and a handler with a non-`Void` output.
    ///   - Parameters:
    ///   - encoder: The encoder object that will be used to encode the generic ``Output`` obtained from the `handler`'s `outputWriter` into a ``ByteBuffer``.
    ///   - decoder: The decoder object that will be used to decode the received ``ByteBuffer`` event into the generic ``Event`` type served to the `handler`.
    ///   - handler: The handler object.
    package init(
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        handler: Handler
    )
    where
        Output: Encodable,
        Output == Handler.Output,
        Encoder == LambdaJSONOutputEncoder<Output>,
        Decoder == JSONDecoder
    {
        self.init(
            encoder: LambdaJSONOutputEncoder(encoder),
            decoder: decoder,
            handler: handler
        )
    }
}

extension NewLambdaRuntime {
    /// Initialize an instance with a ``StreamingLambdaHandler`` in the form of a closure.
    /// - Parameter body: The handler in the form of a closure.
    package convenience init(
        body: @Sendable @escaping (ByteBuffer, LambdaResponseStreamWriter, NewLambdaContext) async throws -> Void
    ) where Handler == StreamingClosureHandler {
        self.init(handler: StreamingClosureHandler(body: body))
    }

    /// Initialize an instance with a ``NewLambdaHandler`` defined in the form of a closure **with a non-`Void` return type**, an encoder, and a decoder.
    /// - Parameter body: The handler in the form of a closure.
    /// - Parameter encoder: The encoder object that will be used to encode the generic ``Output`` into a ``ByteBuffer``.
    /// - Parameter decoder: The decoder object that will be used to decode the incoming ``ByteBuffer`` event into the generic ``Event`` type.
    package convenience init<
        Event: Decodable,
        Output: Encodable,
        Encoder: LambdaOutputEncoder,
        Decoder: LambdaEventDecoder
    >(
        encoder: Encoder,
        decoder: Decoder,
        body: @escaping (Event, NewLambdaContext) async throws -> Output
    )
    where
        Handler == LambdaCodableAdapter<
            LambdaHandlerAdapter<Event, Output, ClosureHandler<Event, Output>>,
            Event,
            Output,
            Decoder,
            Encoder
        >
    {
        let handler = LambdaCodableAdapter(
            encoder: encoder,
            decoder: decoder,
            handler: LambdaHandlerAdapter(handler: ClosureHandler(body: body))
        )

        self.init(handler: handler)
    }

    /// Initialize an instance with a ``NewLambdaHandler`` defined in the form of a closure **with a `Void` return type**, an encoder, and a decoder.
    /// - Parameter body: The handler in the form of a closure.
    /// - Parameter encoder: The encoder object that will be used to encode the generic ``Output`` into a ``ByteBuffer``.
    /// - Parameter decoder: The decoder object that will be used to decode the incoming ``ByteBuffer`` event into the generic ``Event`` type.
    package convenience init<Event: Decodable, Decoder: LambdaEventDecoder>(
        decoder: Decoder,
        body: @escaping (Event, NewLambdaContext) async throws -> Void
    )
    where
        Handler == LambdaCodableAdapter<
            LambdaHandlerAdapter<Event, Void, ClosureHandler<Event, Void>>,
            Event,
            Void,
            Decoder,
            VoidEncoder
        >
    {
        let handler = LambdaCodableAdapter(
            decoder: decoder,
            handler: LambdaHandlerAdapter(handler: ClosureHandler(body: body))
        )

        self.init(handler: handler)
    }

    /// Initialize an instance with a ``NewLambdaHandler`` defined in the form of a closure **with a non-`Void` return type**.
    /// - note: ``JSONEncoder`` and ``JSONDecoder`` are used as the encoder and decoder objects. Use ``init(encoder:decoder:body:)`` to specify custom encoder and decoder objects.
    /// - Parameter body: The handler in the form of a closure.
    package convenience init<Event: Decodable, Output>(
        body: @escaping (Event, NewLambdaContext) async throws -> Output
    )
    where
        Handler == LambdaCodableAdapter<
            LambdaHandlerAdapter<Event, Output, ClosureHandler<Event, Output>>,
            Event,
            Output,
            JSONDecoder,
            LambdaJSONOutputEncoder<Output>
        >
    {
        let handler = LambdaCodableAdapter(
            encoder: JSONEncoder(),
            decoder: JSONDecoder(),
            handler: LambdaHandlerAdapter(handler: ClosureHandler(body: body))
        )

        self.init(handler: handler)
    }

    /// Initialize an instance with a ``NewLambdaHandler`` defined in the form of a closure **with a `Void` return type**.
    /// - note: ``JSONDecoder`` is used as the decoder object. Use ``init(decoder:body:)`` to specify a custom decoder object.
    /// - Parameter body: The handler in the form of a closure.
    package convenience init<Event: Decodable>(
        body: @escaping (Event, NewLambdaContext) async throws -> Void
    )
    where
        Handler == LambdaCodableAdapter<
            LambdaHandlerAdapter<Event, Void, ClosureHandler<Event, Void>>,
            Event,
            Void,
            JSONDecoder,
            VoidEncoder
        >
    {
        let handler = LambdaCodableAdapter(
            decoder: JSONDecoder(),
            handler: LambdaHandlerAdapter(handler: ClosureHandler(body: body))
        )

        self.init(handler: handler)
    }
}
