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

@_exported import AWSLambdaRuntimeCore
import NIOCore

import ServiceLifecycle
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
#endif

///
/// Encapsulate a LambdaRuntime+Codable to offer the same API but this time exposed as a Swift Service
/// This allows to continue to avoid the Service payload for Lambda functions that doesn't need it
///
public class LambdaRuntimeService<Handler>: Service, @unchecked Sendable where Handler: StreamingLambdaHandler  {

    private let runtime: LambdaRuntime<Handler>

    /// Initialize an instance with a `LambdaHandler` defined in the form of a closure **with a non-`Void` return type**.
    /// - Parameters:
    ///   - decoder: The decoder object that will be used to decode the incoming `ByteBuffer` event into the generic `Event` type. `JSONDecoder()` used as default.
    ///   - encoder: The encoder object that will be used to encode the generic `Output` into a `ByteBuffer`. `JSONEncoder()` used as default.
    ///   - body: The handler in the form of a closure.
    public init<Event: Decodable, Output>(
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        body: sending @escaping (Event, LambdaContext) async throws -> Output
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

        self.runtime = LambdaRuntime(handler: handler)
    }

    /// Initialize an instance with a `LambdaHandler` defined in the form of a closure **with a `Void` return type**.
    /// - Parameter body: The handler in the form of a closure.
    /// - Parameter decoder: The decoder object that will be used to decode the incoming `ByteBuffer` event into the generic `Event` type. `JSONDecoder()` used as default.
    public init<Event: Decodable>(
        decoder: JSONDecoder = JSONDecoder(),
        body: sending @escaping (Event, LambdaContext) async throws -> Void
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

        self.runtime = LambdaRuntime(handler: handler)
    }

    public func run() async throws {
        try await self.runtime.run()
    }
}