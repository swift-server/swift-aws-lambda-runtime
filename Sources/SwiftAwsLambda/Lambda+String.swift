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
    /// Run a Lambda defined by implementing the `StringLambdaClosure` function.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ closure: @escaping StringLambdaClosure) {
        self.run(StringLambdaClosureWrapper(closure))
    }

    // for testing
    @inlinable
    internal static func run(configuration: Configuration = .init(), _ closure: @escaping StringLambdaClosure) -> Result<Int, Error> {
        return self.run(configuration: configuration, handler: StringLambdaClosureWrapper(closure))
    }
}

/// A processing closure for a Lambda that takes a `String` and returns a `Result<String, Error>` via a `CompletionHandler`  asynchronously.
public typealias StringLambdaClosure = (Lambda.Context, String, @escaping (Result<String, Error>) -> Void) -> Void

@usableFromInline
internal struct StringLambdaClosureWrapper: LambdaHandler {
    @usableFromInline
    typealias In = String
    @usableFromInline
    typealias Out = String

    private let closure: StringLambdaClosure

    @usableFromInline
    init(_ closure: @escaping StringLambdaClosure) {
        self.closure = closure
    }

    @usableFromInline
    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        self.closure(context, payload, callback)
    }
}

/// Implementation of  a`ByteBuffer` to `String` and `String` to `ByteBuffer` codec
public extension LambdaHandler where In == String, Out == String {
    func encode(allocator: ByteBufferAllocator, value: String) throws -> ByteBuffer? {
        var buffer = allocator.buffer(capacity: value.utf8.count)
        buffer.writeString(value)
        return buffer
    }

    func decode(buffer: ByteBuffer) throws -> String {
        guard let string = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
            throw Errors.invalidBuffer
        }
        return string
    }
}

public extension LambdaHandler where In == String, Out == Void {
    func encode(allocator: ByteBufferAllocator, value: Void) throws -> ByteBuffer? {
        return nil
    }

    func decode(buffer: ByteBuffer) throws -> String {
        guard let string = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
            throw Errors.invalidBuffer
        }
        return string
    }
}

private enum Errors: Error {
    case invalidBuffer
}
