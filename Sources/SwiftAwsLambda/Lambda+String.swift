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
    internal static func run(configuration: Configuration = .init(), _ closure: @escaping LambdaStringClosure) -> LambdaLifecycleResult {
        return self.run(handler: LambdaClosureWrapper(closure), configuration: configuration)
    }

    // for testing
    internal static func run(handler: LambdaStringHandler, configuration: Configuration = .init()) -> LambdaLifecycleResult {
        return self.run(handler: handler as LambdaHandler, configuration: configuration)
    }
}

/// A result type for a Lambda that returns a `String`.
public typealias LambdaStringResult = Result<String, Error>

/// A callback for a Lambda that returns a `LambdaStringResult` result type.
public typealias LambdaStringCallback = (LambdaStringResult) -> Void

/// A processing closure for a Lambda that takes a `String` and returns a `LambdaStringResult` via `LambdaStringCallback` asynchronously.
public typealias LambdaStringClosure = (Lambda.Context, String, LambdaStringCallback) -> Void

/// A processing protocol for a Lambda that takes a `String` and returns a `LambdaStringResult` via `LambdaStringCallback` asynchronously.
public protocol LambdaStringHandler: LambdaHandler {
    func handle(context: Lambda.Context, payload: String, callback: @escaping LambdaStringCallback)
}

/// Default implementation of `String` -> `[UInt8]` encoding and `[UInt8]` -> `String' decoding
public extension LambdaStringHandler {
    func handle(context: Lambda.Context, payload: [UInt8], callback: @escaping LambdaCallback) {
        self.handle(context: context, payload: String(decoding: payload, as: UTF8.self)) { result in
            switch result {
            case .success(let string):
                return callback(.success([UInt8](string.utf8)))
            case .failure(let error):
                return callback(.failure(error))
            }
        }
    }
}

private struct LambdaClosureWrapper: LambdaStringHandler {
    private let closure: LambdaStringClosure
    init(_ closure: @escaping LambdaStringClosure) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, payload: String, callback: @escaping LambdaStringCallback) {
        self.closure(context, payload, callback)
    }
}
