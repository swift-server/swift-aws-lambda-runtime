//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

/// The protocol a decoder must conform to so that it can be used with ``LambdaCodableAdapter`` to decode incoming
/// ``ByteBuffer`` events.
package protocol LambdaEventDecoder {
    /// Decode the ``ByteBuffer`` representing the received event into the generic ``Event`` type
    /// the handler will receive.
    /// - Parameters:
    ///   - type: The type of the object to decode the buffer into.
    ///   - buffer: The buffer to be decoded.
    /// - Returns: An object containing the decoded data.
    func decode<Event: Decodable>(_ type: Event.Type, from buffer: ByteBuffer) throws -> Event
}

/// The protocol an encoder must conform to so that it can be used with ``LambdaCodableAdapter`` to encode the generic
/// ``Output`` object into a ``ByteBuffer``.
package protocol LambdaOutputEncoder {
    associatedtype Output

    /// Encode the generic type `Output` the handler has returned into a ``ByteBuffer``.
    /// - Parameters:
    ///   - value: The object to encode into a ``ByteBuffer``.
    ///   - buffer: The ``ByteBuffer`` where the encoded value will be written to.
    func encode(_ value: Output, into buffer: inout ByteBuffer) throws
}

package struct VoidEncoder: LambdaOutputEncoder {
    package typealias Output = Void

    @inlinable
    package func encode(_ value: Void, into buffer: inout NIOCore.ByteBuffer) throws {}
}

/// Adapts a ``NewLambdaHandler`` conforming handler to conform to ``LambdaWithBackgroundProcessingHandler``.
package struct LambdaHandlerAdapter<
    Event: Decodable,
    Output,
    Handler: NewLambdaHandler
>: LambdaWithBackgroundProcessingHandler where Handler.Event == Event, Handler.Output == Output {
    @usableFromInline let handler: Handler

    /// Initializes an instance given a concrete handler.
    /// - Parameter handler: The ``NewLambdaHandler`` conforming handler that is to be adapted to ``LambdaWithBackgroundProcessingHandler``.
    @inlinable
    package init(handler: Handler) {
        self.handler = handler
    }

    /// Passes the generic ``Event`` object to the ``NewLambdaHandler/handle(_:context:)`` function, and
    /// the resulting output is then written to ``LambdaWithBackgroundProcessingHandler``'s `outputWriter`.
    /// - Parameters:
    ///   - event: The received event.
    ///   - outputWriter: The writer to write the computed response to.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    @inlinable
    package func handle(
        _ event: Event,
        outputWriter: some LambdaResponseWriter<Output>,
        context: NewLambdaContext
    ) async throws {
        let output = try await self.handler.handle(event, context: context)
        try await outputWriter.write(output)
    }
}

/// Adapts a ``LambdaWithBackgroundProcessingHandler`` conforming handler to conform to ``StreamingLambdaHandler``.
package struct LambdaCodableAdapter<
    Handler: LambdaWithBackgroundProcessingHandler,
    Event: Decodable,
    Output,
    Decoder: LambdaEventDecoder,
    Encoder: LambdaOutputEncoder
>: StreamingLambdaHandler where Handler.Event == Event, Handler.Output == Output, Encoder.Output == Output {
    @usableFromInline let handler: Handler
    @usableFromInline let encoder: Encoder
    @usableFromInline let decoder: Decoder
    //
    @usableFromInline var byteBuffer: ByteBuffer = .init()

    /// Initializes an instance given an encoder, decoder, and a handler with a non-`Void` output.
    ///   - Parameters:
    ///   - encoder: The encoder object that will be used to encode the generic ``Output`` obtained from the `handler`'s `outputWriter` into a ``ByteBuffer``.
    ///   - decoder: The decoder object that will be used to decode the received ``ByteBuffer`` event into the generic ``Event`` type served to the `handler`.
    ///   - handler: The handler object.
    @inlinable
    package init(encoder: Encoder, decoder: Decoder, handler: Handler) where Output: Encodable {
        self.encoder = encoder
        self.decoder = decoder
        self.handler = handler
    }

    /// Initializes an instance given a decoder, and a handler with a `Void` output.
    ///   - Parameters:
    ///   - decoder: The decoder object that will be used to decode the received ``ByteBuffer`` event into the generic ``Event`` type served to the `handler`.
    ///   - handler: The handler object.
    @inlinable
    package init(decoder: Decoder, handler: Handler) where Output == Void, Encoder == VoidEncoder {
        self.encoder = VoidEncoder()
        self.decoder = decoder
        self.handler = handler
    }

    /// A ``StreamingLambdaHandler/handle(_:responseWriter:context:)`` wrapper.
    ///   - Parameters:
    ///   - event: The received event.
    ///   - outputWriter: The writer to write the computed response to.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    @inlinable
    package mutating func handle<Writer: LambdaResponseStreamWriter>(
        _ request: ByteBuffer,
        responseWriter: Writer,
        context: NewLambdaContext
    ) async throws {
        let event = try self.decoder.decode(Event.self, from: request)

        let writer = LambdaCodableResponseWriter<Output, Encoder, Writer>(
            encoder: self.encoder,
            streamWriter: responseWriter
        )
        try await self.handler.handle(event, outputWriter: writer, context: context)
    }
}

/// A ``LambdaResponseStreamWriter`` wrapper that conforms to ``LambdaResponseWriter``.
package struct LambdaCodableResponseWriter<Output, Encoder: LambdaOutputEncoder, Base: LambdaResponseStreamWriter>:
    LambdaResponseWriter
where Output == Encoder.Output {
    @usableFromInline let underlyingStreamWriter: Base
    @usableFromInline let encoder: Encoder

    /// Initializes an instance given an encoder and an underlying ``LambdaResponseStreamWriter``.
    /// - Parameters:
    ///   - encoder: The encoder object that will be used to encode the generic ``Output`` into a ``ByteBuffer``, which will then be passed to `streamWriter`.
    ///   - streamWriter: The underlying ``LambdaResponseStreamWriter`` that will be wrapped.
    @inlinable
    package init(encoder: Encoder, streamWriter: Base) {
        self.encoder = encoder
        self.underlyingStreamWriter = streamWriter
    }

    @inlinable
    package func write(_ output: Output) async throws {
        var outputBuffer = ByteBuffer()
        try self.encoder.encode(output, into: &outputBuffer)
        try await self.underlyingStreamWriter.writeAndFinish(outputBuffer)
    }
}
