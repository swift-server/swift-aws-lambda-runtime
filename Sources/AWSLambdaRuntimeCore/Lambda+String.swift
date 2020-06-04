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
import NIO

/// Extension to the `Lambda` companion to enable execution of Lambdas that take and return `String` events.
extension Lambda {
    /// An asynchronous Lambda Closure that takes a `String` and returns a `Result<String, Error>` via a completion handler.
    public typealias StringClosure = (Lambda.Context, String, @escaping (Result<String, Error>) -> Void) -> Void

    /// Run a Lambda defined by implementing the `StringClosure` function.
    ///
    /// - parameters:
    ///     - closure: `StringClosure` based Lambda.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ closure: @escaping StringClosure) {
        self.run(closure: closure)
    }

    /// An asynchronous Lambda Closure that takes a `String` and returns a `Result<Void, Error>` via a completion handler.
    public typealias StringVoidClosure = (Lambda.Context, String, @escaping (Result<Void, Error>) -> Void) -> Void

    /// Run a Lambda defined by implementing the `StringVoidClosure` function.
    ///
    /// - parameters:
    ///     - closure: `StringVoidClosure` based Lambda.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ closure: @escaping StringVoidClosure) {
        self.run(closure: closure)
    }

    // for testing
    @discardableResult
    internal static func run(configuration: Configuration = .init(), closure: @escaping StringClosure) -> Result<Int, Error> {
        self.run(configuration: configuration, handler: StringClosureWrapper(closure))
    }

    // for testing
    @discardableResult
    internal static func run(configuration: Configuration = .init(), closure: @escaping StringVoidClosure) -> Result<Int, Error> {
        self.run(configuration: configuration, handler: StringVoidClosureWrapper(closure))
    }
}

internal struct StringClosureWrapper: LambdaHandler {
    typealias In = String
    typealias Out = String

    private let closure: Lambda.StringClosure

    init(_ closure: @escaping Lambda.StringClosure) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, event: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, event, callback)
    }
}

internal struct StringVoidClosureWrapper: LambdaHandler {
    typealias In = String
    typealias Out = Void

    private let closure: Lambda.StringVoidClosure

    init(_ closure: @escaping Lambda.StringVoidClosure) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, event: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, event, callback)
    }
}

public extension EventLoopLambdaHandler where In == String {
    /// Implementation of a `ByteBuffer` to `String` decoding
    func decode(buffer: ByteBuffer) throws -> String {
        var buffer = buffer
        guard let string = buffer.readString(length: buffer.readableBytes) else {
            fatalError("buffer.readString(length: buffer.readableBytes) failed")
        }
        return string
    }
}

public extension EventLoopLambdaHandler where Out == String {
    /// Implementation of `String` to `ByteBuffer` encoding
    func encode(allocator: ByteBufferAllocator, value: String) throws -> ByteBuffer? {
        // FIXME: reusable buffer
        var buffer = allocator.buffer(capacity: value.utf8.count)
        buffer.writeString(value)
        return buffer
    }
}
