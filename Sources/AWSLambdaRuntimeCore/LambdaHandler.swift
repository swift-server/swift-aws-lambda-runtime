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

import Dispatch
import NIOCore

// MARK: - LambdaHandler

#if compiler(>=5.5) && canImport(_Concurrency)
/// Strongly typed, processing protocol for a Lambda that takes a user defined `Event` and returns a user defined `Output` async.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol LambdaHandler: EventLoopLambdaHandler {
    /// The Lambda initialization method
    /// Use this method to initialize resources that will be used in every request.
    ///
    /// Examples for this can be HTTP or database clients.
    /// - parameters:
    ///     - context: Runtime `InitializationContext`.
    init(context: Lambda.InitializationContext) async throws

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - event: Event of type `Event` representing the event or request.
    ///     - context: Runtime `Context`.
    ///
    /// - Returns: A Lambda result ot type `Output`.
    func handle(_ event: Event, context: LambdaContext) async throws -> Output
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension LambdaHandler {
    public func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Output> {
        let promise = context.eventLoop.makePromise(of: Output.self)
        promise.completeWithTask {
            try await self.handle(event, context: context)
        }
        return promise.futureResult
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension LambdaHandler {
    public static func main() {
        _ = Lambda.run(handlerType: Self.self)
    }
}
#endif

// MARK: - EventLoopLambdaHandler

/// Strongly typed, `EventLoopFuture` based processing protocol for a Lambda that takes a user defined `Event` and returns a user defined `Output` asynchronously.
/// `EventLoopLambdaHandler` extends `ByteBufferLambdaHandler`, performing `ByteBuffer` -> `Event` decoding and `Output` -> `ByteBuffer` encoding.
///
/// - note: To implement a Lambda, implement either `LambdaHandler` or the `EventLoopLambdaHandler` protocol.
///         The `LambdaHandler` will offload the Lambda execution to a `DispatchQueue` making processing safer but slower
///         The `EventLoopLambdaHandler` will execute the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires
///         more care from the implementation to never block the `EventLoop`.
public protocol EventLoopLambdaHandler: ByteBufferLambdaHandler {
    associatedtype Event
    associatedtype Output

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime `Context`.
    ///     - event: Event of type `Event` representing the event or request.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response of type `Output` or an `Error`
    func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Output>

    /// Encode a response of type `Output` to `ByteBuffer`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///     - allocator: A `ByteBufferAllocator` to help allocate the `ByteBuffer`.
    ///     - value: Response of type `Output`.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(allocator: ByteBufferAllocator, value: Output) throws -> ByteBuffer?

    /// Decode a`ByteBuffer` to a request or event of type `Event`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type `Event`.
    func decode(buffer: ByteBuffer) throws -> Event
}

extension EventLoopLambdaHandler {
    /// Driver for `ByteBuffer` -> `Event` decoding and `Output` -> `ByteBuffer` encoding
    @inlinable
    public func handle(_ event: ByteBuffer, context: LambdaContext) -> EventLoopFuture<ByteBuffer?> {
        let input: Event
        do {
            input = try self.decode(buffer: event)
        } catch {
            return context.eventLoop.makeFailedFuture(CodecError.requestDecoding(error))
        }

        return self.handle(input, context: context).flatMapThrowing { output in
            do {
                return try self.encode(allocator: context.allocator, value: output)
            } catch {
                throw CodecError.responseEncoding(error)
            }
        }
    }
}

/// Implementation of  `ByteBuffer` to `Void` decoding
extension EventLoopLambdaHandler where Output == Void {
    @inlinable
    public func encode(allocator: ByteBufferAllocator, value: Void) throws -> ByteBuffer? {
        nil
    }
}

// MARK: - ByteBufferLambdaHandler

/// An `EventLoopFuture` based processing protocol for a Lambda that takes a `ByteBuffer` and returns a `ByteBuffer?` asynchronously.
///
/// - note: This is a low level protocol designed to power the higher level `EventLoopLambdaHandler` and `LambdaHandler` based APIs.
///         Most users are not expected to use this protocol.
public protocol ByteBufferLambdaHandler {
    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime `Context`.
    ///     - event: The event or input payload encoded as `ByteBuffer`.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response encoded as `ByteBuffer` or an `Error`
    func handle(_ event: ByteBuffer, context: LambdaContext) -> EventLoopFuture<ByteBuffer?>

    /// Clean up the Lambda resources asynchronously.
    /// Concrete Lambda handlers implement this method to shutdown resources like `HTTPClient`s and database connections.
    ///
    /// - Note: In case your Lambda fails while creating your LambdaHandler in the `HandlerFactory`, this method
    ///         **is not invoked**. In this case you must cleanup the created resources immediately in the `HandlerFactory`.
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void>
}

extension ByteBufferLambdaHandler {
    public func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        context.eventLoop.makeSucceededFuture(())
    }
}

@usableFromInline
enum CodecError: Error {
    case requestDecoding(Error)
    case responseEncoding(Error)
}
