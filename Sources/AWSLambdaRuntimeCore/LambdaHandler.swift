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
import NIO

// MARK: - LambdaHandler

/// Strongly typed, callback based processing protocol for a Lambda that takes a user defined `In` and returns a user defined `Out` asynchronously.
/// `LambdaHandler` implements `EventLoopLambdaHandler`, performing callback to `EventLoopFuture` mapping, over a `DispatchQueue` for safety.
///
/// - note: To implement a Lambda, implement either `LambdaHandler` or the `EventLoopLambdaHandler` protocol.
///         The `LambdaHandler` will offload the Lambda execution to a `DispatchQueue` making processing safer but slower.
///         The `EventLoopLambdaHandler` will execute the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires
///         more care from the implementation to never block the `EventLoop`.
public protocol LambdaHandler: EventLoopLambdaHandler {
    /// Defines to which `DispatchQueue` the Lambda execution is offloaded to.
    var offloadQueue: DispatchQueue { get }

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime `Context`.
    ///     - event: Event of type `In` representing the event or request.
    ///     - callback: Completion handler to report the result of the Lambda back to the runtime engine.
    ///                 The completion handler expects a `Result` with either a response of type `Out` or an `Error`
    func handle(context: Lambda.Context, event: In, callback: @escaping (Result<Out, Error>) -> Void)
}

internal extension Lambda {
    static let defaultOffloadQueue = DispatchQueue(label: "LambdaHandler.offload")
}

public extension LambdaHandler {
    /// The queue on which `handle` is invoked on.
    var offloadQueue: DispatchQueue {
        Lambda.defaultOffloadQueue
    }

    /// `LambdaHandler` is offloading the processing to a `DispatchQueue`
    /// This is slower but safer, in case the implementation blocks the `EventLoop`
    /// Performance sensitive Lambdas should be based on `EventLoopLambdaHandler` which does not offload.
    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        let promise = context.eventLoop.makePromise(of: Out.self)
        // FIXME: reusable DispatchQueue
        self.offloadQueue.async {
            self.handle(context: context, event: event, callback: promise.completeWith)
        }
        return promise.futureResult
    }
}

public extension LambdaHandler {
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        let promise = context.eventLoop.makePromise(of: Void.self)
        self.offloadQueue.async {
            do {
                try self.syncShutdown(context: context)
                promise.succeed(())
            } catch {
                promise.fail(error)
            }
        }
        return promise.futureResult
    }

    /// Clean up the Lambda resources synchronously.
    /// Concrete Lambda handlers implement this method to shutdown resources like `HTTPClient`s and database connections.
    func syncShutdown(context: Lambda.ShutdownContext) throws {
        // noop
    }
}

// MARK: - EventLoopLambdaHandler

/// Strongly typed, `EventLoopFuture` based processing protocol for a Lambda that takes a user defined `In` and returns a user defined `Out` asynchronously.
/// `EventLoopLambdaHandler` extends `ByteBufferLambdaHandler`, performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.
///
/// - note: To implement a Lambda, implement either `LambdaHandler` or the `EventLoopLambdaHandler` protocol.
///         The `LambdaHandler` will offload the Lambda execution to a `DispatchQueue` making processing safer but slower
///         The `EventLoopLambdaHandler` will execute the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires
///         more care from the implementation to never block the `EventLoop`.
public protocol EventLoopLambdaHandler: ByteBufferLambdaHandler {
    associatedtype In
    associatedtype Out

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime `Context`.
    ///     - event: Event of type `In` representing the event or request.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response of type `Out` or an `Error`
    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out>

    /// Encode a response of type `Out` to `ByteBuffer`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///     - allocator: A `ByteBufferAllocator` to help allocate the `ByteBuffer`.
    ///     - value: Response of type `Out`.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer?

    /// Decode a`ByteBuffer` to a request or event of type `In`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type `In`.
    func decode(buffer: ByteBuffer) throws -> In
}

public extension EventLoopLambdaHandler {
    /// Driver for `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding
    func handle(context: Lambda.Context, event: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
        switch self.decodeIn(buffer: event) {
        case .failure(let error):
            return context.eventLoop.makeFailedFuture(CodecError.requestDecoding(error))
        case .success(let `in`):
            return self.handle(context: context, event: `in`).flatMapThrowing { out in
                switch self.encodeOut(allocator: context.allocator, value: out) {
                case .failure(let error):
                    throw CodecError.responseEncoding(error)
                case .success(let buffer):
                    return buffer
                }
            }
        }
    }

    private func decodeIn(buffer: ByteBuffer) -> Result<In, Error> {
        do {
            return .success(try self.decode(buffer: buffer))
        } catch {
            return .failure(error)
        }
    }

    private func encodeOut(allocator: ByteBufferAllocator, value: Out) -> Result<ByteBuffer?, Error> {
        do {
            return .success(try self.encode(allocator: allocator, value: value))
        } catch {
            return .failure(error)
        }
    }
}

/// Implementation of  `ByteBuffer` to `Void` decoding
public extension EventLoopLambdaHandler where Out == Void {
    func encode(allocator: ByteBufferAllocator, value: Void) throws -> ByteBuffer? {
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
    func handle(context: Lambda.Context, event: ByteBuffer) -> EventLoopFuture<ByteBuffer?>

    /// Clean up the Lambda resources asynchronously.
    /// Concrete Lambda handlers implement this method to shutdown resources like `HTTPClient`s and database connections.
    ///
    /// - Note: In case your Lambda fails while creating your LambdaHandler in the `HandlerFactory`, this method
    ///         **is not invoked**. In this case you must cleanup the created resources immediately in the `HandlerFactory`.
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void>
}

public extension ByteBufferLambdaHandler {
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        context.eventLoop.makeSucceededFuture(())
    }
}

private enum CodecError: Error {
    case requestDecoding(Error)
    case responseEncoding(Error)
}
