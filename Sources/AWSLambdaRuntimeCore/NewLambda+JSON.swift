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
import NIOFoundationCompat

import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

package protocol LambdaEventDecoder {
    func decode<Event: Decodable>(_ type: Event.Type, from buffer: ByteBuffer) throws -> Event
}

package protocol LambdaOutputEncoder {
    func encode<Output: Encodable>(_ value: Output, into buffer: inout ByteBuffer) throws
}

extension JSONEncoder: LambdaOutputEncoder {}

extension JSONDecoder: LambdaEventDecoder {}

package struct VoidEncoder: LambdaOutputEncoder {
    package func encode<Output>(_ value: Output, into buffer: inout NIOCore.ByteBuffer) throws where Output: Encodable {
        fatalError("LambdaOutputEncoder must never be called on a void output")
    }
}

package struct LambdaHandlerAdapter<
    Event: Decodable,
    Output,
    Handler: NewLambdaHandler
>: LambdaWithBackgroundProcessingHandler where Handler.Event == Event, Handler.Output == Output {
    let handler: Handler

    package init(handler: Handler) {
        self.handler = handler
    }

    package func handle(
        _ event: Event,
        outputWriter: consuming some LambdaResponseWriter<Output>,
        context: NewLambdaContext
    ) async throws {
        let response = try await self.handler.handle(event, context: context)
        try await outputWriter.write(response: response)
    }
}

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

    package init(encoder: Encoder, decoder: Decoder, handler: Handler) where Output: Encodable {
        self.encoder = encoder
        self.decoder = decoder
        self.handler = handler
    }

    package init(decoder: Decoder, handler: Handler) where Output == Void, Encoder == VoidEncoder {
        self.encoder = VoidEncoder()
        self.decoder = decoder
        self.handler = handler
    }

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

package struct ResponseWriter<Output>: LambdaResponseWriter {
    let underlyingStreamWriter: LambdaResponseStreamWriter
    let encoder: LambdaOutputEncoder
    var byteBuffer = ByteBuffer()

    package init(encoder: LambdaOutputEncoder, streamWriter: LambdaResponseStreamWriter) {
        self.encoder = encoder
        self.underlyingStreamWriter = streamWriter
    }

    package mutating func write(response: Output) async throws {
        if Output.self == Void.self {
            try await self.underlyingStreamWriter.finish()
        } else if let response = response as? Encodable {
            try self.encoder.encode(response, into: &self.byteBuffer)
            try await self.underlyingStreamWriter.writeAndFinish(self.byteBuffer)
        }
    }
}
