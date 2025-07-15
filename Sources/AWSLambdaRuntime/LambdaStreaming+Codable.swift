//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A streaming handler protocol that receives a decoded JSON event and can stream responses.
/// This handler protocol supports response streaming and background work execution.
/// Background work can be executed after closing the response stream by calling
/// ``LambdaResponseStreamWriter/finish()`` or ``LambdaResponseStreamWriter/writeAndFinish(_:)``.
public protocol StreamingLambdaHandlerWithEvent: _Lambda_SendableMetatype {
    /// Generic input type that will be decoded from JSON.
    associatedtype Event: Decodable

    /// The handler function that receives a decoded event and can stream responses.
    /// - Parameters:
    ///   - event: The decoded event object.
    ///   - responseWriter: A ``LambdaResponseStreamWriter`` to write the invocation's response to.
    ///     If no response or error is written to `responseWriter` an error will be reported to the invoker.
    ///   - context: The ``LambdaContext`` containing the invocation's metadata.
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
        _ event: Event,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws
}

/// Adapts a ``StreamingLambdaHandlerWithEvent`` to work as a ``StreamingLambdaHandler``
/// by handling JSON decoding of the input event.
public struct StreamingLambdaCodableAdapter<
    Handler: StreamingLambdaHandlerWithEvent,
    Decoder: LambdaEventDecoder
>: StreamingLambdaHandler where Handler.Event: Decodable {
    @usableFromInline var handler: Handler
    @usableFromInline let decoder: Decoder

    /// Initialize with a custom decoder and handler.
    /// - Parameters:
    ///   - decoder: The decoder to use for parsing the input event.
    ///   - handler: The streaming handler that works with decoded events.
    @inlinable
    public init(decoder: sending Decoder, handler: sending Handler) {
        self.decoder = decoder
        self.handler = handler
    }

    /// Handles the raw ByteBuffer by decoding it and passing to the underlying handler.
    /// - Parameters:
    ///   - event: The raw ByteBuffer event to decode.
    ///   - responseWriter: The response writer to pass to the underlying handler.
    ///   - context: The Lambda context.
    @inlinable
    public mutating func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {

        // for some reasons I don't understand the "body" param contains the complete FunctionURL request
        // so, 1/ we decode the event we receive, 2/ we base64 decode the body, 3/ we decode a FunnctionURLRequest again,
        // then 4/ we can access the actual payload body, decode it pass it to the handler
        let functionUrlEvent1 = try self.decoder.decode(FunctionURLRequest.self, from: event)
        if let base64EncodedString = functionUrlEvent1.body,

            // this is the minimal way to base64 decode without importing new dependecies
            let decodedData = Data(base64Encoded: base64EncodedString),
            let decodedString = String(data: decodedData, encoding: .utf8)
        {

            // decode the FunCtionURL event inside the body
            let functionUrlEvent2 = try self.decoder.decode(
                FunctionURLRequest.self,
                from: ByteBuffer(string: decodedString)
            )

            // finally decode the actual payload passed by the caller
            let decodedEvent = try self.decoder.decode(
                Handler.Event.self,
                from: ByteBuffer(string: functionUrlEvent2.body ?? "")
            )

            // and invoke the user-provided handler
            try await self.handler.handle(decodedEvent, responseWriter: responseWriter, context: context)
        } else {
            context.logger.trace("Can't decode FunctionURLRequest's body", metadata: ["Event": "\(event)"])
        }
    }
}

/// A closure-based streaming handler that works with decoded JSON events.
/// Allows for a streaming handler to be defined in a clean manner, leveraging Swift's trailing closure syntax.
public struct StreamingFromEventClosureHandler<Event: Decodable>: StreamingLambdaHandlerWithEvent {
    let body: @Sendable (Event, LambdaResponseStreamWriter, LambdaContext) async throws -> Void

    /// Initialize with a closure that receives a decoded event.
    /// - Parameter body: The handler closure that receives a decoded event, response writer, and context.
    public init(
        body: @Sendable @escaping (Event, LambdaResponseStreamWriter, LambdaContext) async throws -> Void
    ) {
        self.body = body
    }

    /// Calls the provided closure with the decoded event.
    /// - Parameters:
    ///   - event: The decoded event object.
    ///   - responseWriter: The response writer for streaming output.
    ///   - context: The Lambda context.
    public func handle(
        _ event: Event,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {
        try await self.body(event, responseWriter, context)
    }
}

#if FoundationJSONSupport
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import class Foundation.JSONDecoder
#endif

extension StreamingLambdaCodableAdapter {
    /// Initialize with a JSON decoder and handler.
    /// - Parameters:
    ///   - decoder: The JSON decoder to use. Defaults to `JSONDecoder()`.
    ///   - handler: The streaming handler that works with decoded events.
    public init(
        decoder: JSONDecoder = JSONDecoder(),
        handler: sending Handler
    ) where Decoder == LambdaJSONEventDecoder {
        self.init(decoder: LambdaJSONEventDecoder(decoder), handler: handler)
    }
}

extension LambdaRuntime {
    /// Initialize with a streaming handler that receives decoded JSON events.
    /// - Parameters:
    ///   - decoder: The JSON decoder to use. Defaults to `JSONDecoder()`.
    ///   - logger: The logger to use. Defaults to a logger with label "LambdaRuntime".
    ///   - streamingBody: The handler closure that receives a decoded event.
    public convenience init<Event: Decodable>(
        decoder: JSONDecoder = JSONDecoder(),
        logger: Logger = Logger(label: "LambdaRuntime"),
        streamingBody: @Sendable @escaping (Event, LambdaResponseStreamWriter, LambdaContext) async throws -> Void
    )
    where
        Handler == StreamingLambdaCodableAdapter<
            StreamingFromEventClosureHandler<Event>,
            LambdaJSONEventDecoder
        >
    {
        let closureHandler = StreamingFromEventClosureHandler(body: streamingBody)
        let adapter = StreamingLambdaCodableAdapter(
            decoder: decoder,
            handler: closureHandler
        )
        self.init(handler: adapter, logger: logger)
    }

    /// Initialize with a custom streaming handler that receives decoded events.
    /// - Parameters:
    ///   - decoder: The decoder to use for parsing input events.
    ///   - handler: The streaming handler.
    ///   - logger: The logger to use.
    public convenience init<StreamingHandler: StreamingLambdaHandlerWithEvent, Decoder: LambdaEventDecoder>(
        decoder: sending Decoder,
        handler: sending StreamingHandler,
        logger: Logger = Logger(label: "LambdaRuntime")
    ) where Handler == StreamingLambdaCodableAdapter<StreamingHandler, Decoder> {
        let adapter = StreamingLambdaCodableAdapter(decoder: decoder, handler: handler)
        self.init(handler: adapter, logger: logger)
    }
}
#endif  // FoundationJSONSupport
