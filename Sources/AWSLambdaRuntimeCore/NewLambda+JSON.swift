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
    /// Encode the generic type `Output` the handler has returned into a ``ByteBuffer``.
    /// - Parameters:
    ///   - value: The object to encode into a ``ByteBuffer``.
    ///   - buffer: The ``ByteBuffer`` where the encoded value will be written to.
    func encode<Output: Encodable>(_ value: Output, into buffer: inout ByteBuffer) throws
}

package struct VoidEncoder: LambdaOutputEncoder {
    package func encode<Output>(_ value: Output, into buffer: inout NIOCore.ByteBuffer) throws where Output: Encodable {
        fatalError("LambdaOutputEncoder must never be called on a void output")
    }
}

/// Adapts a ``NewLambdaHandler`` conforming handler to conform to ``LambdaWithBackgroundProcessingHandler``.
package struct LambdaHandlerAdapter<
    Event: Decodable,
    Output,
    Handler: NewLambdaHandler
>: LambdaWithBackgroundProcessingHandler where Handler.Event == Event, Handler.Output == Output {
    let handler: Handler

    /// Initializes an instance given a concrete handler.
    /// - Parameter handler: The ``NewLambdaHandler`` conforming handler that is to be adapted to ``LambdaWithBackgroundProcessingHandler``.
    package init(handler: Handler) {
        self.handler = handler
    }

    /// Passes the generic ``Event`` object to the ``NewLambdaHandler/handle(_:context:)`` function, and
    /// the resulting output is then written to ``LambdaWithBackgroundProcessingHandler``'s `outputWriter`.
    /// - Parameters:
    ///   - event: The received event.
    ///   - outputWriter: The writer to write the computed response to.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    package func handle(
        _ event: Event,
        outputWriter: consuming some LambdaResponseWriter<Output>,
        context: NewLambdaContext
    ) async throws {
        let response = try await self.handler.handle(event, context: context)
        try await outputWriter.write(response: response)
    }
}

/// Adapts a ``LambdaWithBackgroundProcessingHandler`` conforming handler to conform to ``StreamingLambdaHandler``.
package struct LambdaCodableAdapter<
    Handler: LambdaWithBackgroundProcessingHandler,
    Event: Decodable,
    Output,
    Decoder: LambdaEventDecoder,
    Encoder: LambdaOutputEncoder
>: StreamingLambdaHandler where Handler.Event == Event, Handler.Output == Output {
    let handler: Handler
    let encoder: Encoder
    let decoder: Decoder
    private var byteBuffer: ByteBuffer = .init()

    /// Initializes an instance given an encoder, decoder, and a handler with a non-`Void` output.
    ///   - Parameters:
    ///   - encoder: The encoder object that will be used to encode the generic ``Output`` obtained from the `handler`'s `outputWriter` into a ``ByteBuffer``.
    ///   - decoder: The decoder object that will be used to decode the received ``ByteBuffer`` event into the generic ``Event`` type served to the `handler`.
    ///   - handler: The handler object.
    package init(encoder: Encoder, decoder: Decoder, handler: Handler) where Output: Encodable {
        self.encoder = encoder
        self.decoder = decoder
        self.handler = handler
    }

    /// Initializes an instance given a decoder, and a handler with a `Void` output.
    ///   - Parameters:
    ///   - decoder: The decoder object that will be used to decode the received ``ByteBuffer`` event into the generic ``Event`` type served to the `handler`.
    ///   - handler: The handler object.
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
    package mutating func handle(
        _ request: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: NewLambdaContext
    ) async throws {
        let event = try self.decoder.decode(Event.self, from: request)

        let writer = ResponseWriter<Output>(encoder: self.encoder, streamWriter: responseWriter)
        try await self.handler.handle(event, outputWriter: writer, context: context)
    }
}

/// A ``LambdaResponseStreamWriter`` wrapper that conforms to ``LambdaResponseWriter``.
package struct ResponseWriter<Output>: LambdaResponseWriter {
    let underlyingStreamWriter: LambdaResponseStreamWriter
    let encoder: LambdaOutputEncoder
    var byteBuffer = ByteBuffer()

    /// Initializes an instance given an encoder and an underlying ``LambdaResponseStreamWriter``.
    /// - Parameters:
    ///   - encoder: The encoder object that will be used to encode the generic ``Output`` into a ``ByteBuffer``, which will then be passed to `streamWriter`.
    ///   - streamWriter: The underlying ``LambdaResponseStreamWriter`` that will be wrapped.
    package init(encoder: LambdaOutputEncoder, streamWriter: LambdaResponseStreamWriter) {
        self.encoder = encoder
        self.underlyingStreamWriter = streamWriter
    }

    ///  Passes the `response` argument to ``LambdaResponseStreamWriter/writeAndFinish(_:)``.
    /// - Parameter response: The generic ``Output`` object that will be passed to ``LambdaResponseStreamWriter/writeAndFinish(_:)``.
    package mutating func write(response: Output) async throws {
        if Output.self == Void.self {
            try await self.underlyingStreamWriter.finish()
        } else if let response = response as? Encodable {
            try self.encoder.encode(response, into: &self.byteBuffer)
            try await self.underlyingStreamWriter.writeAndFinish(self.byteBuffer)
        }
    }
}
