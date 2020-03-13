//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
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
    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void)
}

public extension LambdaHandler {
    /// `LambdaHandler` is offloading the processing to a `DispatchQueue`
    /// This is slower but safer, in case the implementation blocks the `EventLoop`
    /// Performance sensitive Lambdas should be based on `EventLoopLambdaHandler` which does not offload.
    func handle(context: Lambda.Context, payload: In) -> EventLoopFuture<Out> {
        let promise = context.eventLoop.makePromise(of: Out.self)
        // FIXME: reusable DispatchQueue
        DispatchQueue(label: "LambdaHandler.offload").async {
            self.handle(context: context, payload: payload, callback: promise.completeWith)
        }
        return promise.futureResult
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

    func handle(context: Lambda.Context, payload: In) -> EventLoopFuture<Out>

    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer?
    func decode(buffer: ByteBuffer) throws -> In
}

/// Driver for `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding
public extension EventLoopLambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
        switch self.decodeIn(buffer: payload) {
        case .failure(let error):
            return context.eventLoop.makeFailedFuture(CodecError.requestDecoding(error))
        case .success(let `in`):
            return self.handle(context: context, payload: `in`).flatMapThrowing { out in
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

// MARK: - ByteBufferLambdaHandler

/// An `EventLoopFuture` based processing protocol for a Lambda that takes a `ByteBuffer` and returns a `ByteBuffer?` asynchronously.
///
/// - note: This is a low level protocol designed to power the higher level `EventLoopLambdaHandler` and `LambdaHandler` based APIs.
///         Most users are not expected to use this protocol.
public protocol ByteBufferLambdaHandler {
    /// Handles the Lambda request.
    func handle(context: Lambda.Context, payload: ByteBuffer) -> EventLoopFuture<ByteBuffer?>
}

private enum CodecError: Error {
    case requestDecoding(Error)
    case responseEncoding(Error)
}
