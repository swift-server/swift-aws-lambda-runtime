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

import Foundation

extension Lambda {
    public static func run<In: Decodable, Out: Encodable>(_ closure: @escaping LambdaCodableClosure<In, Out>) {
        self.run(LambdaClosureWrapper(closure))
    }

    public static func run<T>(_ handler: T) where T: LambdaCodableHandler {
        self.run(handler as LambdaHandler)
    }

    // for testing
    internal static func run<In: Decodable, Out: Encodable>(maxTimes: Int = 0, _ closure: @escaping LambdaCodableClosure<In, Out>) -> LambdaLifecycleResult {
        return self.run(handler: LambdaClosureWrapper(closure), maxTimes: maxTimes)
    }

    // for testing
    internal static func run<T>(handler: T, maxTimes: Int = 0) -> LambdaLifecycleResult where T: LambdaCodableHandler {
        return self.run(handler: handler as LambdaHandler, maxTimes: maxTimes)
    }
}

public typealias LambdaCodableResult<Out> = Result<Out, String>

public typealias LambdaCodableCallback<Out> = (LambdaCodableResult<Out>) -> Void

public typealias LambdaCodableClosure<In, Out> = (LambdaContext, In, LambdaCodableCallback<Out>) -> Void

public protocol LambdaCodableHandler: LambdaHandler {
    associatedtype In: Decodable
    associatedtype Out: Encodable

    func handle(context: LambdaContext, payload: In, callback: @escaping LambdaCodableCallback<Out>)
    var codec: LambdaCodableCodec<In, Out> { get }
}

// default uses json codec. advanced users that want to inject their own codec can do it here
public extension LambdaCodableHandler {
    var codec: LambdaCodableCodec<In, Out> {
        return LambdaCodableJsonCodec<In, Out>()
    }
}

// TODO: would be nicer to use a protocol instead of this "abstract class", but generics get in the way
public class LambdaCodableCodec<In: Decodable, Out: Encodable> {
    func encode(_: Out) -> [UInt8]? { return nil }
    func decode(_: [UInt8]) -> In? { return nil }
}

public extension LambdaCodableHandler {
    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping (LambdaResult) -> Void) {
        guard let payloadAsCodable = codec.decode(payload) else {
            return callback(.failure("failed decoding payload (in)"))
        }
        self.handle(context: context, payload: payloadAsCodable, callback: { result in
            switch result {
            case let .success(encodable):
                guard let codableAsBytes = self.codec.encode(encodable) else {
                    return callback(.failure("failed encoding result (out)"))
                }
                return callback(.success(codableAsBytes))
            case let .failure(error):
                return callback(.failure(error))
            }
        })
    }
}

// This is a class as encoder amd decoder are a class, which means its cheaper to hold a reference to both in a class then a struct.
private class LambdaCodableJsonCodec<In: Decodable, Out: Encodable>: LambdaCodableCodec<In, Out> {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    public override func encode(_ value: Out) -> [UInt8]? {
        return try? [UInt8](self.encoder.encode(value))
    }

    public override func decode(_ data: [UInt8]) -> In? {
        return try? self.decoder.decode(In.self, from: Data(data))
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
