//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import NIO
import NIOFoundationCompat

/// Extension to the `Lambda` companion to enable execution of Lambdas that take and return `Codable` payloads.
extension Lambda {
    /// Run a Lambda defined by implementing the `CodableLambdaClosure` function.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run<In: Decodable, Out: Encodable>(_ closure: @escaping CodableLambdaClosure<In, Out>) {
        self.run(closure: closure)
    }

    /// Run a Lambda defined by implementing the `CodableVoidLambdaClosure` function.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run<In: Decodable>(_ closure: @escaping CodableVoidLambdaClosure<In>) {
        self.run(closure: closure)
    }

    // for testing
    @inlinable
    @discardableResult
    internal static func run<In: Decodable, Out: Encodable>(configuration: Configuration = .init(), closure: @escaping CodableLambdaClosure<In, Out>) -> Result<Int, Error> {
        return self.run(configuration: configuration, handler: CodableLambdaClosureWrapper(closure))
    }

    // for testing
    @inlinable
    @discardableResult
    internal static func run<In: Decodable>(configuration: Configuration = .init(), closure: @escaping CodableVoidLambdaClosure<In>) -> Result<Int, Error> {
        return self.run(configuration: configuration, handler: CodableVoidLambdaClosureWrapper(closure))
    }
}

/// A processing closure for a Lambda that takes a `In` and returns a `Result<Out, Error>` via a `CompletionHandler` asynchronously.
public typealias CodableLambdaClosure<In: Decodable, Out: Encodable> = (Lambda.Context, In, @escaping (Result<Out, Error>) -> Void) -> Void

/// A processing closure for a Lambda that takes a `In` and returns a `Result<Void, Error>` via a `CompletionHandler` asynchronously.
public typealias CodableVoidLambdaClosure<In: Decodable> = (Lambda.Context, In, @escaping (Result<Void, Error>) -> Void) -> Void

@usableFromInline
internal struct CodableLambdaClosureWrapper<In: Decodable, Out: Encodable>: LambdaHandler {
    @usableFromInline
    typealias In = In
    @usableFromInline
    typealias Out = Out

    private let closure: CodableLambdaClosure<In, Out>

    @usableFromInline
    init(_ closure: @escaping CodableLambdaClosure<In, Out>) {
        self.closure = closure
    }

    @usableFromInline
    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, payload, callback)
    }
}

@usableFromInline
internal struct CodableVoidLambdaClosureWrapper<In: Decodable>: LambdaHandler {
    @usableFromInline
    typealias In = In
    @usableFromInline
    typealias Out = Void

    private let closure: CodableVoidLambdaClosure<In>

    @usableFromInline
    init(_ closure: @escaping CodableVoidLambdaClosure<In>) {
        self.closure = closure
    }

    @usableFromInline
    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, payload, callback)
    }
}

/// Implementation of  a`ByteBuffer` to `In` and `Out` to `ByteBuffer` codec
/// Using Foundation's JSONEncoder and JSONDecoder
/// Advanced users that want to inject their own codec can do it by overriding these functions.
public extension EventLoopLambdaHandler where In: Decodable, Out: Encodable {
    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer? {
        // nio will resize the buffer if necessary
        // FIXME: reusable JSONEncoder and buffer
        var buffer = allocator.buffer(capacity: 1024)
        try JSONEncoder().encode(value, into: &buffer)
        return buffer
    }

    func decode(buffer: ByteBuffer) throws -> In {
        // FIXME: reusable JSONDecoder
        return try JSONDecoder().decode(In.self, from: buffer)
    }
}

public extension EventLoopLambdaHandler where In: Decodable, Out == Void {
    func encode(allocator: ByteBufferAllocator, value: Void) throws -> ByteBuffer? {
        return nil
    }

    func decode(buffer: ByteBuffer) throws -> In {
        // FIXME: reusable JSONDecoder
        return try JSONDecoder().decode(In.self, from: buffer)
    }
}
