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

package protocol StreamingLambdaHandler {
    mutating func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: NewLambdaContext
    ) async throws
}

package protocol LambdaResponseStreamWriter {
    mutating func write(_ buffer: ByteBuffer) async throws
    func finish() async throws
    func writeAndFinish(_ buffer: ByteBuffer) async throws
    func reportError(_ error: any Error) async throws
}

package protocol NewLambdaHandler {
    associatedtype Event: Decodable
    associatedtype Output

    func handle(_ event: Event, context: NewLambdaContext) async throws -> Output
}

package protocol LambdaWithBackgroundProcessingHandler {
    associatedtype Event: Decodable
    associatedtype Output

    /// The business logic of the Lambda function. Receives a generic input type and returns a generic output type.
    /// Agnostic to JSON encoding/decoding
    func handle(
        _ event: Event,
        outputWriter: some LambdaResponseWriter<Output>,
        context: NewLambdaContext
    ) async throws
}

package protocol LambdaResponseWriter<Output>: ~Copyable {
    associatedtype Output
    /// Sends the generic Output object (representing the computed result of the handler)
    /// to the AWS Lambda response endpoint.
    /// This function simply serves as a mechanism to return the computed result from a handler function
    /// without an explicit `return`.
    mutating func write(response: Output) async throws
}

package struct StreamingClosureHandler: StreamingLambdaHandler {
    let body: @Sendable (ByteBuffer, LambdaResponseStreamWriter, NewLambdaContext) async throws -> Void

    package init(
        body: @Sendable @escaping (ByteBuffer, LambdaResponseStreamWriter, NewLambdaContext) async throws -> Void
    ) {
        self.body = body
    }

    package func handle(
        _ request: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: NewLambdaContext
    ) async throws {
        try await self.body(request, responseWriter, context)
    }
}

package struct ClosureHandler<Event: Decodable, Output>: NewLambdaHandler {
    let body: (Event, NewLambdaContext) async throws -> Output

    package init(body: @escaping (Event, NewLambdaContext) async throws -> Output) where Output: Encodable {
        self.body = body
    }

    package init(body: @escaping (Event, NewLambdaContext) async throws -> Void) where Output == Void {
        self.body = body
    }

    package func handle(_ event: Event, context: NewLambdaContext) async throws -> Output {
        try await self.body(event, context)
    }
}
