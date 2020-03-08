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

import NIO

/// Extension to the `Lambda` companion to enable execution of Lambdas that take and return `String` payloads.
extension Lambda {
    /// Run a Lambda defined by implementing the `StringLambda.Closure` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ closure: @escaping StringLambda.Closure) {
        self.run(ClosureWrapper(closure))
    }

    /// Run a Lambda defined by implementing the `StringLambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ handler: StringLambdaHandler) {
        self.run { _ in handler }
    }

    /// Run a Lambda defined by implementing the `StringLambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ provider: @escaping (EventLoop) throws -> StringLambdaHandler) {
        self.run(provider: { try provider($0) as LambdaHandler })
    }

    // for testing
    internal static func run(configuration: Configuration = .init(), closure: @escaping StringLambda.Closure) -> Result<Int, Error> {
        return self.run(handler: ClosureWrapper(closure), configuration: configuration)
    }

    // for testing
    internal static func run(handler: StringLambdaHandler, configuration: Configuration = .init()) -> Result<Int, Error> {
        return self.run(handler: handler as LambdaHandler, configuration: configuration)
    }

    // for testing
    internal static func run(provider: @escaping (EventLoop) throws -> StringLambdaHandler, configuration: Configuration = .init()) -> Result<Int, Error> {
        return self.run(provider: { try provider($0) as LambdaHandler }, configuration: configuration)
    }
}

public enum StringLambda {
    /// A completion handler for a Lambda that returns a `Result<String, Error>` result type.
    public typealias CompletionHandler = (Result<String, Error>?) -> Void

    /// A processing closure for a Lambda that takes a `String` and returns a `Result<String, Error>` via `CompletionHandler` asynchronously.
    public typealias Closure = (Lambda.Context, String, CompletionHandler) -> Void
}

/// A processing protocol for a Lambda that takes a `String` and returns an optional `String`  asynchronously via an `CompletionHandler`.
public protocol StringLambdaHandler: LambdaHandler {
    func handle(context: Lambda.Context, payload: String, callback: @escaping StringLambda.CompletionHandler)
}

/// A processing protocol for a Lambda that takes a `String` and returns an optional `String`  asynchronously via an `EventLoopPromise`.
public protocol StringPromiseLambdaHandler: LambdaHandler {
    func handle(context: Lambda.Context, payload: String, promise: EventLoopPromise<String?>)
}

/// Default implementation of `String` -> `ByteBuffer` encoding and `ByteBuffer` -> `String` decoding
public extension StringLambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        guard let payload = payload.getString(at: payload.readerIndex, length: payload.readableBytes) else {
            return promise.fail(Errors.invalidBuffer)
        }
        self.handle(context: context, payload: payload) { result in
            switch result {
            case .none:
                promise.succeed(nil)
            case .failure(let error):
                promise.fail(error)
            case .success(let string):
                var buffer = context.allocator.buffer(capacity: string.utf8.count)
                buffer.writeString(string)
                promise.succeed(buffer)
            }
        }
    }
}

/// Default implementation of `String` -> `ByteBuffer` encoding and `ByteBuffer` -> `String` decoding
public extension StringPromiseLambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        guard let payload = payload.getString(at: payload.readerIndex, length: payload.readableBytes) else {
            return promise.fail(Errors.invalidBuffer)
        }
        let stringPromise = context.eventLoop.makePromise(of: String?.self)
        stringPromise.futureResult.map { string in
            string.flatMap { string in
                var buffer = context.allocator.buffer(capacity: string.utf8.count)
                buffer.writeString(string)
                return buffer
            }
        }.cascade(to: promise)
        self.handle(context: context, payload: payload, promise: stringPromise)
    }
}

private struct ClosureWrapper: StringLambdaHandler {
    private let closure: StringLambda.Closure

    init(_ closure: @escaping StringLambda.Closure) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, payload: String, callback: @escaping StringLambda.CompletionHandler) {
        self.closure(context, payload, callback)
    }
}

private enum Errors: Error {
    case invalidBuffer
}
