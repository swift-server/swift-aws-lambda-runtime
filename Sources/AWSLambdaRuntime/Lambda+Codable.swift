//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
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
    /// - parameters:
    ///     - closure: `CodableLambdaClosure` based Lambda.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<In: Decodable, Out: Encodable>(_ closure: @escaping CodableLambdaClosure<In, Out>) {
        self.run(closure: closure)
    }

    /// Run a Lambda defined by implementing the `CodableVoidLambdaClosure` function.
    ///
    /// - parameters:
    ///     - closure: `CodableVoidLambdaClosure` based Lambda.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<In: Decodable>(_ closure: @escaping CodableVoidLambdaClosure<In>) {
        self.run(closure: closure)
    }

    // for testing
    @discardableResult
    internal static func run<In: Decodable, Out: Encodable>(configuration: Configuration = .init(), closure: @escaping CodableLambdaClosure<In, Out>) -> Result<Int, Error> {
        self.run(configuration: configuration, handler: CodableLambdaClosureWrapper(closure))
    }

    // for testing
    @discardableResult
    internal static func run<In: Decodable>(configuration: Configuration = .init(), closure: @escaping CodableVoidLambdaClosure<In>) -> Result<Int, Error> {
        self.run(configuration: configuration, handler: CodableVoidLambdaClosureWrapper(closure))
    }
}

/// An asynchronous Lambda Closure that takes a `In: Decodable` and returns a `Result<Out: Encodable, Error>` via a completion handler.
public typealias CodableLambdaClosure<In: Decodable, Out: Encodable> = (Lambda.Context, In, @escaping (Result<Out, Error>) -> Void) -> Void

/// An asynchronous Lambda Closure that takes a `In: Decodable` and returns a `Result<Void, Error>` via a completion handler.
public typealias CodableVoidLambdaClosure<In: Decodable> = (Lambda.Context, In, @escaping (Result<Void, Error>) -> Void) -> Void

internal struct CodableLambdaClosureWrapper<In: Decodable, Out: Encodable>: LambdaHandler {
    typealias In = In
    typealias Out = Out

    private let closure: CodableLambdaClosure<In, Out>

    init(_ closure: @escaping CodableLambdaClosure<In, Out>) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, payload, callback)
    }
}

internal struct CodableVoidLambdaClosureWrapper<In: Decodable>: LambdaHandler {
    typealias In = In
    typealias Out = Void

    private let closure: CodableVoidLambdaClosure<In>

    init(_ closure: @escaping CodableVoidLambdaClosure<In>) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, payload, callback)
    }
}

/// Implementation of  a`ByteBuffer` to `In` decoding
public extension EventLoopLambdaHandler where In: Decodable {
    func decode(buffer: ByteBuffer) throws -> In {
        try self.decoder.decode(In.self, from: buffer)
    }
}

/// Implementation of  `Out` to `ByteBuffer` encoding
public extension EventLoopLambdaHandler where Out: Encodable {
    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer? {
        try self.encoder.encode(value, using: allocator)
    }
}

/// Default `ByteBuffer` to `In` decoder using Foundation's JSONDecoder
/// Advanced users that want to inject their own codec can do it by overriding these functions.
public extension EventLoopLambdaHandler where In: Decodable {
    var decoder: LambdaCodableDecoder {
        Lambda.defaultJSONDecoder
    }
}

/// Default `Out` to `ByteBuffer` encoder using Foundation's JSONEncoder
/// Advanced users that want to inject their own codec can do it by overriding these functions.
public extension EventLoopLambdaHandler where Out: Encodable {
    var encoder: LambdaCodableEncoder {
        Lambda.defaultJSONEncoder
    }
}

public protocol LambdaCodableDecoder {
    func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T
}

public protocol LambdaCodableEncoder {
    func encode<T: Encodable>(_ value: T, using allocator: ByteBufferAllocator) throws -> ByteBuffer
}

private extension Lambda {
    static let defaultJSONDecoder = JSONDecoder()
    static let defaultJSONEncoder = JSONEncoder()
}

extension JSONDecoder: LambdaCodableDecoder {}
extension JSONEncoder: LambdaCodableEncoder {
    public func encode<T>(_ value: T, using allocator: ByteBufferAllocator) throws -> ByteBuffer where T: Encodable {
        // nio will resize the buffer if necessary
        var buffer = allocator.buffer(capacity: 1024)
        try self.encode(value, into: &buffer)
        return buffer
    }
}
