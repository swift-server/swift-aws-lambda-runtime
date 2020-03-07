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
    /// Run a Lambda defined by implementing the `LambdaStringClosure` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ closure: @escaping LambdaStringClosure) {
        self.run(LambdaClosureWrapper(closure))
    }

    /// Run a Lambda defined by implementing the `LambdaStringHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ handler: LambdaStringHandler) {
        self.run(handler as LambdaHandler)
    }

    // for testing
    internal static func run(configuration: Configuration = .init(), _ closure: @escaping LambdaStringClosure) -> Result<Int, Error> {
        return self.run(handler: LambdaClosureWrapper(closure), configuration: configuration)
    }

    // for testing
    internal static func run(handler: LambdaStringHandler, configuration: Configuration = .init()) -> Result<Int, Error> {
        return self.run(handler: handler as LambdaHandler, configuration: configuration)
    }
}

/// A callback for a Lambda that returns a `Result<String, Error>` result type.
public typealias LambdaStringCallback = (Result<String, Error>) -> Void

/// A processing closure for a Lambda that takes a `String` and returns a `LambdaStringResult` via `LambdaStringCallback` asynchronously.
public typealias LambdaStringClosure = (LambdaContext, String, LambdaStringCallback) -> Void

/// A processing protocol for a Lambda that takes a `String` and returns a `LambdaStringResult` via `LambdaStringCallback` asynchronously.
public protocol LambdaStringHandler: LambdaHandler {
    func handle(context: LambdaContext, payload: String, callback: @escaping LambdaStringCallback)
}

/// Default implementation of `String` -> `[UInt8]` encoding and `[UInt8]` -> `String' decoding
public extension LambdaStringHandler {
    func handle(context: LambdaContext, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer>) {
        guard let payload = payload.getString(at: payload.readerIndex, length: payload.readableBytes) else {
            return promise.fail(Errors.invalidBuffer)
        }
        self.handle(context: context, payload: payload) { result in
            switch result {
            case .success(let string):
                var buffer = context.allocator.buffer(capacity: string.utf8.count)
                buffer.writeString(string)
                return promise.succeed(buffer)
            case .failure(let error):
                return promise.fail(error)
            }
        }
    }
}

private struct LambdaClosureWrapper: LambdaStringHandler {
    private let closure: LambdaStringClosure
    init(_ closure: @escaping LambdaStringClosure) {
        self.closure = closure
    }

    func handle(context: LambdaContext, payload: String, callback: @escaping LambdaStringCallback) {
        self.closure(context, payload, callback)
    }
}

private enum Errors: Error {
    case invalidBuffer
}
