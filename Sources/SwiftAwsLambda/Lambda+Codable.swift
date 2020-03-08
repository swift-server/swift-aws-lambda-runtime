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

import Foundation // for JSON
import NIO
import NIOFoundationCompat

/// Extension to the `Lambda` companion to enable execution of Lambdas that take and return `Codable` payloads.
/// This is the most common way to use this library in AWS Lambda, since its JSON based.
extension Lambda {
    /// Run a Lambda defined by implementing the `CodableLambda.Closure` closure, having `In` and `Out` extending `Decodable` and `Encodable` respectively.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<In: Decodable, Out: Encodable>(_ closure: @escaping CodableLambda.Closure<In, Out>) {
        self.run(ClosureWrapper(closure))
    }

    /// Run a Lambda defined by implementing the `CodableLambdaHandler` protocol, having `In` and `Out` are `Decodable` and `Encodable` respectively.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<Handler>(_ handler: Handler) where Handler: CodableLambdaHandler {
        self.run { _ in handler }
    }

    /// Run a Lambda defined by implementing the `CodableLambdaHandler` protocol, having `In` and `Out` are `Decodable` and `Encodable` respectively.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<Handler>(_ provider: @escaping (EventLoop) throws -> Handler) where Handler: CodableLambdaHandler {
        self.run { try provider($0) as LambdaHandler }
    }

    // for testing
    internal static func run<In: Decodable, Out: Encodable>(configuration: Configuration = .init(), closure: @escaping CodableLambda.Closure<In, Out>) -> Result<Int, Error> {
        return self.run(provider: { _ in ClosureWrapper(closure) }, configuration: configuration)
    }

    // for testing
    internal static func run<Handler>(handler: Handler, configuration: Configuration = .init()) -> Result<Int, Error> where Handler: CodableLambdaHandler {
        return self.run(handler: handler as LambdaHandler, configuration: configuration)
    }

    // for testing
    internal static func run<Handler>(provider: @escaping (EventLoop) throws -> Handler, configuration: Configuration = .init()) -> Result<Int, Error> where Handler: CodableLambdaHandler {
        return self.run(provider: { try provider($0) as LambdaHandler }, configuration: configuration)
    }
}

public enum CodableLambda {
    /// A completion handler for a Lambda that returns a `Result<Out, Error>` result type.
    public typealias CompletionHandler<Out> = (Result<Out, Error>?) -> Void

    /// A processing closure for a Lambda that takes a `String` and returns a `Result<Out, Error>` via `CompletionHandler` asynchronously.
    public typealias Closure<In, Out> = (Lambda.Context, In, CompletionHandler<Out>) -> Void
}

/// A processing protocol for a Lambda that takes an `In` and returns an optional `Out`asynchronously via a `CompletionHandler<Out>` ,
/// having `In` and `Out` extending `Decodable` and `Encodable` respectively.
public protocol CodableLambdaHandler: LambdaHandler {
    associatedtype In: Decodable
    associatedtype Out: Encodable

    var codec: LambdaCodableCodec<In, Out> { get }

    func handle(context: Lambda.Context, payload: In, callback: @escaping CodableLambda.CompletionHandler<Out>)
}

/// A processing protocol for a Lambda that takes a `In` and returns an optional `Out`  asynchronously via an `EventLoopPromise`.
public protocol CodablePromiseLambdaHandler: LambdaHandler {
    associatedtype In: Decodable
    associatedtype Out: Encodable

    var codec: LambdaCodableCodec<In, Out> { get }

    func handle(context: Lambda.Context, payload: In, promise: EventLoopPromise<Out?>)
}

/// Default implementation for `CodableLambdaHandler` codec which uses JSON via `LambdaCodableJsonCodec`.
/// Advanced users that want to inject their own codec can do it by overriding this.
public extension CodableLambdaHandler {
    var codec: LambdaCodableCodec<In, Out> {
        LambdaCodableJsonCodec<In, Out>()
    }
}

/// Default implementation for `CodableLambdaHandler` codec which uses JSON via `LambdaCodableJsonCodec`.
/// Advanced users that want to inject their own codec can do it by overriding this.
public extension CodablePromiseLambdaHandler {
    var codec: LambdaCodableCodec<In, Out> {
        LambdaCodableJsonCodec<In, Out>()
    }
}

/// LambdaCodableCodec is an abstract/empty implementation for codec which does `Encodable` -> `ByteBuffer` encoding and `ByteBuffer` -> `Decodable` decoding.
// TODO: would be nicer to use a protocol instead of this "abstract class", but generics get in the way
public class LambdaCodableCodec<In: Decodable, Out: Encodable> {
    func encode(_: Out) -> Result<ByteBuffer, Error> { fatalError("not implmented") }
    func decode(_: ByteBuffer) -> Result<In, Error> { fatalError("not implmented") }
}

/// Default implementation of `Encodable` -> `ByteBuffer` encoding and `ByteBuffer` -> `Decodable` decoding
public extension CodableLambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        switch self.codec.decode(payload) {
        case .failure(let error):
            return promise.fail(Errors.requestDecoding(error))
        case .success(let payloadAsCodable):
            self.handle(context: context, payload: payloadAsCodable) { result in
                switch result {
                case .none:
                    promise.succeed(nil)
                case .failure(let error):
                    promise.fail(error)
                case .success(let encodable):
                    switch self.codec.encode(encodable) {
                    case .failure(let error):
                        promise.fail(Errors.responseEncoding(error))
                    case .success(let buffer):
                        promise.succeed(buffer)
                    }
                }
            }
        }
    }
}

/// Default implementation of `Encodable` -> `ByteBuffer` encoding and `ByteBuffer` -> `Decodable'`decoding
public extension CodablePromiseLambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        switch self.codec.decode(payload) {
        case .failure(let error):
            return promise.fail(Errors.requestDecoding(error))
        case .success(let decodable):
            let encodablePromise = context.eventLoop.makePromise(of: Out?.self)
            encodablePromise.futureResult.flatMapThrowing { encodable in
                try encodable.flatMap { encodable in
                    switch self.codec.encode(encodable) {
                    case .failure(let error):
                        throw Errors.responseEncoding(error)
                    case .success(let buffer):
                        return buffer
                    }
                }
            }.cascade(to: promise)
            self.handle(context: context, payload: decodable, promise: encodablePromise)
        }
    }
}

/// LambdaCodableJsonCodec is an implementation of `LambdaCodableCodec` which does `Encodable` -> `ByteBuffer` encoding and `ByteBuffer` -> `Decodable' decoding
/// using JSONEncoder and JSONDecoder respectively.
// This is a class as encoder amd decoder are a class, which means its cheaper to hold a reference to both in a class then a struct.
private final class LambdaCodableJsonCodec<In: Decodable, Out: Encodable>: LambdaCodableCodec<In, Out> {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let allocator = ByteBufferAllocator()

    public override func encode(_ value: Out) -> Result<ByteBuffer, Error> {
        do {
            let data = try self.encoder.encode(value)
            var buffer = self.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            return .success(buffer)
        } catch {
            return .failure(error)
        }
    }

    public override func decode(_ buffer: ByteBuffer) -> Result<In, Error> {
        do {
            guard let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) else {
                throw Errors.invalidBuffer
            }
            return .success(try self.decoder.decode(In.self, from: data))
        } catch {
            return .failure(error)
        }
    }
}

private struct ClosureWrapper<In: Decodable, Out: Encodable>: CodableLambdaHandler {
    typealias Codec = LambdaCodableJsonCodec<In, Out>

    private let closure: CodableLambda.Closure<In, Out>

    init(_ closure: @escaping CodableLambda.Closure<In, Out>) {
        self.closure = closure
    }

    public func handle(context: Lambda.Context, payload: In, callback: @escaping CodableLambda.CompletionHandler<Out>) {
        self.closure(context, payload, callback)
    }
}

private enum Errors: Error {
    case responseEncoding(Error)
    case requestDecoding(Error)
    case invalidBuffer
}
