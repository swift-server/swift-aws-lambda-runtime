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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
#endif

public struct LambdaJSONEventDecoder: LambdaEventDecoder {
    @usableFromInline let jsonDecoder: JSONDecoder

    @inlinable
    public init(_ jsonDecoder: JSONDecoder) {
        self.jsonDecoder = jsonDecoder
    }

    @inlinable
    public func decode<Event>(_ type: Event.Type, from buffer: NIOCore.ByteBuffer) throws -> Event where Event : Decodable {
        try buffer.getJSONDecodable(
            Event.self,
            decoder: self.jsonDecoder,
            at: buffer.readerIndex,
            length: buffer.readableBytes
        )!  // must work, enough readable bytes
    }
}

public struct LambdaJSONOutputEncoder<Output: Encodable>: LambdaOutputEncoder {
    @usableFromInline let jsonEncoder: JSONEncoder

    @inlinable
    public init(_ jsonEncoder: JSONEncoder) {
        self.jsonEncoder = jsonEncoder
    }

    @inlinable
    public func encode(_ value: Output, into buffer: inout ByteBuffer) throws {
        try buffer.writeJSONEncodable(value, encoder: self.jsonEncoder)
    }
}

extension LambdaCodableAdapter {
    /// Initializes an instance given an encoder, decoder, and a handler with a non-`Void` output.
    ///   - Parameters:
    ///   - encoder: The encoder object that will be used to encode the generic `Output` obtained from the `handler`'s `outputWriter` into a `ByteBuffer`.
    ///   - decoder: The decoder object that will be used to decode the received `ByteBuffer` event into the generic `Event` type served to the `handler`.
    ///   - handler: The handler object.
    public init(
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        handler: Handler
    )
    where
        Output: Encodable,
        Output == Handler.Output,
        Encoder == LambdaJSONOutputEncoder<Output>,
        Decoder == LambdaJSONEventDecoder
    {
        self.init(
            encoder: LambdaJSONOutputEncoder(encoder),
            decoder: LambdaJSONEventDecoder(decoder),
            handler: handler
        )
    }
}

extension LambdaRuntime {
    /// Initialize an instance with a `LambdaHandler` defined in the form of a closure **with a non-`Void` return type**.
    /// - Parameter body: The handler in the form of a closure.
    /// - Parameter encoder: The encoder object that will be used to encode the generic `Output` into a `ByteBuffer`. `JSONEncoder()` used as default.
    /// - Parameter decoder: The decoder object that will be used to decode the incoming `ByteBuffer` event into the generic `Event` type. `JSONDecoder()` used as default.
    public convenience init<Event: Decodable, Output>(
        body: @escaping (Event, LambdaContext) async throws -> Output,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    )
    where
        Handler == LambdaCodableAdapter<
            LambdaHandlerAdapter<Event, Output, ClosureHandler<Event, Output>>,
            Event,
            Output,
            LambdaJSONEventDecoder,
            LambdaJSONOutputEncoder<Output>
        >
    {
        let handler = LambdaCodableAdapter(
            encoder: encoder,
            decoder: decoder,
            handler: LambdaHandlerAdapter(handler: ClosureHandler(body: body))
        )

        self.init(handler: handler)
    }

    /// Initialize an instance with a `LambdaHandler` defined in the form of a closure **with a `Void` return type**.
    /// - Parameter body: The handler in the form of a closure.
    /// - Parameter decoder: The decoder object that will be used to decode the incoming `ByteBuffer` event into the generic `Event` type. `JSONDecoder()` used as default.
    public convenience init<Event: Decodable>(
        body: @escaping (Event, LambdaContext) async throws -> Void,
        decoder: JSONDecoder = JSONDecoder()
    )
    where
        Handler == LambdaCodableAdapter<
            LambdaHandlerAdapter<Event, Void, ClosureHandler<Event, Void>>,
            Event,
            Void,
            LambdaJSONEventDecoder,
            VoidEncoder
        >
    {
        let handler = LambdaCodableAdapter(
            decoder: LambdaJSONEventDecoder(decoder),
            handler: LambdaHandlerAdapter(handler: ClosureHandler(body: body))
        )

        self.init(handler: handler)
    }
}
