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

import NIO

/// Strongly typed, callback based Lamnda.
/// `LambdaHandler` implements `ByteBufferLambdaHandler`,  performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.
///
/// - note: To implement a Lambda, implement either `LambdaHandler` or the `EventLoopLambdaHandler` protocol.
///         The `LambdaHandler` will offload the Lambda execution to a `DispatchQueue` making the procssing safer but slower.
///         The `EventLoopLambdaHandler` will execute the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires
///         more care from the implementation to never block the `EventLoop`.
public protocol LambdaHandler: ByteBufferLambdaHandler {
    associatedtype In
    associatedtype Out

    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void)

    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer?
    func decode(buffer: ByteBuffer) throws -> In
}

public extension LambdaHandler {
    /// The `LambdaHandler` will offload the Lambda execution to a `DispatchQueue` making the procssing safer but slower.
    var offload: Bool { return true }
}

/// Strongly typed, `EventLoopFuture` based  Lambda.
/// `EventLoopLambdaHandler` implements `ByteBufferLambdaHandler`,  performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.
///
/// - note: To implement a Lambda, implement either `LambdaHandler` or the `EventLoopLambdaHandler` protocol.
///         The `LambdaHandler` will offload the Lambda execution to a `DispatchQueue` making the procssing safer but slower
///         The `EventLoopLambdaHandler` will execute the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires
///         more care from the implementation to never  block the `EventLoop`.
public protocol EventLoopLambdaHandler: LambdaHandler {
    func handle(context: Lambda.Context, payload: In) -> EventLoopFuture<Out>
}

public extension EventLoopLambdaHandler {
    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.handle(context: context, payload: payload).whenComplete(callback)
    }

    /// The `EventLoopLambdaHandler` will execute the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires
    var offload: Bool { return false }
}

/// Driver for `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding
public extension LambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
        switch self.decodeIn(buffer: payload) {
        case .failure(let error):
            return context.eventLoop.makeFailedFuture(Lambda.CodecError.requestDecoding(error))
        case .success(let `in`):
            let promise = context.eventLoop.makePromise(of: Out.self)
            self.handle(context: context, payload: `in`, callback: promise.completeWith)
            return promise.futureResult.flatMapThrowing { out in
                switch self.encodeOut(allocator: context.allocator, value: out) {
                case .failure(let error):
                    throw Lambda.CodecError.responseEncoding(error)
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

internal extension Lambda {
    enum CodecError: Error {
        case responseEncoding(Error)
        case requestDecoding(Error)
    }

    struct InvalidLambdaError: Error, CustomStringConvertible {
        let description = "Lambda Handler not implemented correctly, either handle(promise) or handle(callback) must be implemented."
    }
}
