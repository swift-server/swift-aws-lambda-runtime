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

/// Strongly typed `ByteBufferLambdaHandler` that performs `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.
public protocol LambdaHandler: ByteBufferLambdaHandler {
    associatedtype In
    associatedtype Out

    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void)
    func handle(context: Lambda.Context, payload: In, promise: EventLoopPromise<Out>)

    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer?
    func decode(buffer: ByteBuffer) throws -> In
}

/// Default `ByteBufferLambdaHandler` implementation for `LambdaHandler`, performing tranformation between a `CompletionHandler` and `EventLoopPromise`
///
/// - note: Either one of thes `handle` functions  must be implemented (overriden) by the concrete `LambdaHandler` implementation
public extension LambdaHandler {
    func handle(context: Lambda.Context, payload: In, promise: EventLoopPromise<Out>) {
        self.handle(context: context, payload: payload, callback: promise.completeWith)
    }

    func handle(context: Lambda.Context, payload: In, callback: (Result<Out, Error>) -> Void) {
        fatalError("Lambda Handler not implemented correctly, either handler(promise) or handle(callback) must be implemented.")
    }
}

/// Driver for `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding
public extension LambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        switch self.decodeIn(buffer: payload) {
        case .failure(let error):
            return promise.fail(Lambda.CodecError.requestDecoding(error))
        case .success(let `in`):
            let outPromise = context.eventLoop.makePromise(of: Out.self)
            outPromise.futureResult.flatMapThrowing { out in
                switch self.encodeOut(allocator: context.allocator, value: out) {
                case .failure(let error):
                    throw Lambda.CodecError.responseEncoding(error)
                case .success(let buffer):
                    return buffer
                }
            }.cascade(to: promise)
            self.handle(context: context, payload: `in`, promise: outPromise)
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
        case invalidBuffer
    }
}
