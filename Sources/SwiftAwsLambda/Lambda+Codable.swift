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
    /// Run a Lambda defined by implementing the `LambdaCodableClosure` closure, having `In` and `Out` extending `Decodable` and `Encodable` respectively.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<In: Decodable, Out: Encodable>(_ closure: @escaping LambdaCodableClosure<In, Out>) {
        self.run(LambdaClosureWrapper(closure))
    }

    /// Run a Lambda defined by implementing the `LambdaCodableHandler` protocol, having `In` and `Out` are `Decodable` and `Encodable` respectively.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run<Handler>(_ handler: Handler) where Handler: LambdaCodableHandler {
        self.run(handler as LambdaHandler)
    }

    // for testing
    internal static func run<In: Decodable, Out: Encodable>(configuration: Configuration = .init(), closure: @escaping LambdaCodableClosure<In, Out>) -> Result<Int, Error> {
        return self.run(handler: LambdaClosureWrapper(closure), configuration: configuration)
    }

    // for testing
    internal static func run<Handler>(handler: Handler, configuration: Configuration = .init()) -> Result<Int, Error> where Handler: LambdaCodableHandler {
        return self.run(handler: handler as LambdaHandler, configuration: configuration)
    }
}

/// A callback for a Lambda that returns a `Result<Out, Error>` result type, having `Out` extend `Encodable`.
public typealias LambdaCodableCallback<Out> = (Result<Out, Error>) -> Void

/// A processing closure for a Lambda that takes an `In` and returns an `Out` via `LambdaCodableCallback<Out>` asynchronously,
/// having `In` and `Out` extending `Decodable` and `Encodable` respectively.
public typealias LambdaCodableClosure<In, Out> = (LambdaContext, In, LambdaCodableCallback<Out>) -> Void

/// A processing protocol for a Lambda that takes an `In` and returns an `Out` via `LambdaCodableCallback<Out>` asynchronously,
/// having `In` and `Out` extending `Decodable` and `Encodable` respectively.
public protocol LambdaCodableHandler: LambdaHandler {
    associatedtype In: Decodable
    associatedtype Out: Encodable

    func handle(context: LambdaContext, payload: In, callback: @escaping LambdaCodableCallback<Out>)
    var codec: LambdaCodableCodec<In, Out> { get }
}

/// Default implementation for `LambdaCodableHandler` codec which uses JSON via `LambdaCodableJsonCodec`.
/// Advanced users that want to inject their own codec can do it by overriding this.
public extension LambdaCodableHandler {
    var codec: LambdaCodableCodec<In, Out> {
        return LambdaCodableJsonCodec<In, Out>()
    }
}

/// LambdaCodableCodec is an abstract/empty implementation for codec which does `Encodable` -> `[UInt8]` encoding and `[UInt8]` -> `Decodable' decoding.
// TODO: would be nicer to use a protocol instead of this "abstract class", but generics get in the way
public class LambdaCodableCodec<In: Decodable, Out: Encodable> {
    func encode(_: Out) -> Result<ByteBuffer, Error> { fatalError("not implmented") }
    func decode(_: ByteBuffer) -> Result<In, Error> { fatalError("not implmented") }
}

/// Default implementation of `Encodable` -> `[UInt8]` encoding and `[UInt8]` -> `Decodable' decoding
public extension LambdaCodableHandler {
    func handle(context: LambdaContext, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer>) {
        switch self.codec.decode(payload) {
        case .failure(let error):
            return promise.fail(Errors.requestDecoding(error))
        case .success(let payloadAsCodable):
            self.handle(context: context, payload: payloadAsCodable) { result in
                switch result {
                case .failure(let error):
                    return promise.fail(error)
                case .success(let encodable):
                    switch self.codec.encode(encodable) {
                    case .failure(let error):
                        return promise.fail(Errors.responseEncoding(error))
                    case .success(let buffer):
                        return promise.succeed(buffer)
                    }
                }
            }
        }
    }
}

/// LambdaCodableJsonCodec is an implementation of `LambdaCodableCodec` which does `Encodable` -> `[UInt8]` encoding and `[UInt8]` -> `Decodable' decoding
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

private struct LambdaClosureWrapper<In: Decodable, Out: Encodable>: LambdaCodableHandler {
    typealias Codec = LambdaCodableJsonCodec<In, Out>

    private let closure: LambdaCodableClosure<In, Out>
    init(_ closure: @escaping LambdaCodableClosure<In, Out>) {
        self.closure = closure
    }

    public func handle(context: LambdaContext, payload: In, callback: @escaping LambdaCodableCallback<Out>) {
        self.closure(context, payload, callback)
    }
}

private enum Errors: Error {
    case responseEncoding(Error)
    case requestDecoding(Error)
    case invalidBuffer
}
