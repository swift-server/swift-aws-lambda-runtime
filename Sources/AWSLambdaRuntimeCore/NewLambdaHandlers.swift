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

/// The base handler protocol that receives a ``ByteBuffer`` representing the incoming event and returns the response as a ``ByteBuffer`` too.
/// This handler protocol supports response streaming. Bytes can be streamed outwards through the ``LambdaResponseStreamWriter``
/// passed as an argument in the ``handle(_:responseWriter:context:)`` function.
/// Background work can also be executed after returning the response. After closing the response stream by calling
/// ``LambdaResponseStreamWriter/finish()`` or ``LambdaResponseStreamWriter/writeAndFinish(_:)``,
/// the ``handle(_:responseWriter:context:)`` function is free to execute any background work.
package protocol StreamingLambdaHandler {
    /// The handler function -- implement the business logic of the Lambda function here.
    /// - Parameters:
    ///   - event: The invocation's input data.
    ///   - responseWriter: A ``LambdaResponseStreamWriter`` to write the invocation's response to.
    ///   If no response or error is written to `responseWriter` an error will be reported to the invoker.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    /// - Throws:
    /// How the thrown error will be handled by the runtime:
    ///   - An invocation error will be reported if the error is thrown before the first call to
    ///     ``LambdaResponseStreamWriter/write(_:)``.
    ///   - If the error is thrown after call(s) to ``LambdaResponseStreamWriter/write(_:)`` but before
    ///     a call to ``LambdaResponseStreamWriter/finish()``, the response stream will be closed and trailing
    ///     headers will be sent.
    ///   - If ``LambdaResponseStreamWriter/finish()`` has already been called before the error is thrown, the
    ///     error will be logged.
    mutating func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: NewLambdaContext
    ) async throws
}

/// A writer object to write the Lambda response stream into. The HTTP response is started lazily.
/// before the first call to ``write(_:)`` or ``writeAndFinish(_:)``.
package protocol LambdaResponseStreamWriter {
    /// Write a response part into the stream. Bytes written are streamed continually.
    /// - Parameter buffer: The buffer to write.
    func write(_ buffer: ByteBuffer) async throws

    /// End the response stream and the underlying HTTP response.
    func finish() async throws

    /// Write a response part into the stream and then end the stream as well as the underlying HTTP response.
    /// - Parameter buffer: The buffer to write.
    func writeAndFinish(_ buffer: ByteBuffer) async throws
}

/// This handler protocol is intended to serve the most common use-cases.
/// This protocol is completely agnostic to any encoding/decoding -- decoding the received event invocation into an ``Event`` object and encoding the returned ``Output`` object is handled by the library.
/// The``handle(_:context:)`` function simply receives the generic ``Event`` object as input and returns the generic ``Output`` object.
///
/// - note: This handler protocol does not support response streaming because the output has to be encoded prior to it being sent, e.g. it is not possible to encode a partial/incomplete JSON string.
/// This protocol also does not support the execution of background work after the response has been returned -- the ``LambdaWithBackgroundProcessingHandler`` protocol caters for such use-cases.
package protocol NewLambdaHandler {
    /// Generic input type.
    /// The body of the request sent to Lambda will be decoded into this type for the handler to consume.
    associatedtype Event: Decodable
    /// Generic output type.
    /// This is the return type of the ``handle(_:context:)`` function.
    associatedtype Output

    /// Implement the business logic of the Lambda function here.
    /// - Parameters:
    ///   - event: The generic ``Event`` object representing the invocation's input data.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    /// - Returns: A generic ``Output`` object representing the computed result.
    func handle(_ event: Event, context: NewLambdaContext) async throws -> Output
}

/// This protocol is exactly like ``NewLambdaHandler``, with the only difference being the added support for executing background
/// work after the result has been sent to the AWS Lambda control plane.
/// This is achieved by not having a return type in the `handle` function. The output is instead written into a
/// ``LambdaResponseWriter``that is passed in as an argument, meaning that the ``handle(_:)`` function is then free to implement
/// any background work after the result has been sent to the AWS Lambda control plane.
package protocol LambdaWithBackgroundProcessingHandler {
    /// Generic input type.
    /// The body of the request sent to Lambda will be decoded into this type for the handler to consume.
    associatedtype Event: Decodable
    /// Generic output type.
    /// This is the type that the `handle` function will send through the ``LambdaResponseWriter``.
    associatedtype Output

    /// Implement the business logic of the Lambda function here.
    /// - Parameters:
    ///   - event: The generic ``Event`` object representing the invocation's input data.
    ///   - outputWriter: The writer to send the computed response to. A call to `outputWriter.write(_:)` will return the response to the AWS Lambda response endpoint.
    ///   Any background work can then be executed before returning.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    func handle(
        _ event: Event,
        outputWriter: some LambdaResponseWriter<Output>,
        context: NewLambdaContext
    ) async throws
}

/// Used with ``LambdaWithBackgroundProcessingHandler``.
/// A mechanism to "return" an output from ``LambdaWithBackgroundProcessingHandler/handle(_:outputWriter:context:)`` without the function needing to
/// have a return type and exit at that point. This allows for background work to be executed _after_ a response has been sent to the AWS Lambda response endpoint.
package protocol LambdaResponseWriter<Output> {
    associatedtype Output
    /// Sends the generic ``Output`` object (representing the computed result of the handler)
    /// to the AWS Lambda response endpoint.
    /// This function simply serves as a mechanism to return the computed result from a handler function
    /// without an explicit `return`.
    func write(_ output: Output) async throws
}

/// A ``StreamingLambdaHandler`` conforming handler object that can be constructed with a closure.
/// Allows for a handler to be defined in a clean manner, leveraging Swift's trailing closure syntax.
package struct StreamingClosureHandler: StreamingLambdaHandler {
    let body: @Sendable (ByteBuffer, LambdaResponseStreamWriter, NewLambdaContext) async throws -> Void

    /// Initialize an instance from a handler function in the form of a closure.
    /// - Parameter body: The handler function written as a closure.
    package init(
        body: @Sendable @escaping (ByteBuffer, LambdaResponseStreamWriter, NewLambdaContext) async throws -> Void
    ) {
        self.body = body
    }

    /// Calls the provided `self.body` closure with the ``ByteBuffer`` invocation event, the ``LambdaResponseStreamWriter``, and the ``NewLambdaContext``
    /// - Parameters:
    ///   - event: The invocation's input data.
    ///   - responseWriter: A ``LambdaResponseStreamWriter`` to write the invocation's response to.
    ///   If no response or error is written to `responseWriter` an error will be reported to the invoker.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    package func handle(
        _ request: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: NewLambdaContext
    ) async throws {
        try await self.body(request, responseWriter, context)
    }
}

/// A ``NewLambdaHandler`` conforming handler object that can be constructed with a closure.
/// Allows for a handler to be defined in a clean manner, leveraging Swift's trailing closure syntax.
package struct ClosureHandler<Event: Decodable, Output>: NewLambdaHandler {
    let body: (Event, NewLambdaContext) async throws -> Output

    /// Initialize with a closure handler over generic `Input` and `Output` types.
    /// - Parameter body: The handler function written as a closure.
    package init(body: @escaping (Event, NewLambdaContext) async throws -> Output) where Output: Encodable {
        self.body = body
    }

    /// Initialize with a closure handler over a generic `Input` type, and a `Void` `Output`.
    /// - Parameter body: The handler function written as a closure.
    package init(body: @escaping (Event, NewLambdaContext) async throws -> Void) where Output == Void {
        self.body = body
    }

    /// Calls the provided `self.body` closure with the generic ``Event`` object representing the incoming event, and the ``NewLambdaContext``
    /// - Parameters:
    ///   - event: The generic ``Event`` object representing the invocation's input data.
    ///   - context: The ``NewLambdaContext`` containing the invocation's metadata.
    package func handle(_ event: Event, context: NewLambdaContext) async throws -> Output {
        try await self.body(event, context)
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
}
