//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import NIOCore

// MARK: - LambdaHandler

#if compiler(>=5.5) && canImport(_Concurrency)
/// Strongly typed, processing protocol for a Lambda that takes a user defined
/// ``EventLoopLambdaHandler/Event`` and returns a user defined
/// ``EventLoopLambdaHandler/Output`` asynchronously.
///
/// - note: Most users should implement this protocol instead of the lower
///         level protocols ``EventLoopLambdaHandler`` and
///         ``ByteBufferLambdaHandler``.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol LambdaHandler: EventLoopLambdaHandler {
    /// The lambda functions input. In most cases this should be `Codable`. If your event originates from an
    /// AWS service, have a look at [AWSLambdaEvents](https://github.com/swift-server/swift-aws-lambda-events),
    /// which provides a number of commonly used AWS Event implementations.
    associatedtype Event = Self.Event where Event == Self.Event
    /// The lambda functions output. Can be `Void`.
    associatedtype Output = Self.Output where Output == Self.Output
    
    /// The empty Lambda initialization method.
    /// Use this method to initialize resources that will be used in every request.
    ///
    /// Examples for this can be HTTP or database clients.
    init() async throws
    
    /// The Lambda initialization method.
    /// Use this method to initialize resources that will be used in every request. Defaults to
    /// calling ``LambdaHandler/init()``
    ///
    /// Examples for this can be HTTP or database clients.
    /// - parameters:
    ///     - context: Runtime ``LambdaInitializationContext``.
    init(context: LambdaInitializationContext) async throws

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - event: Event of type `Event` representing the event or request.
    ///     - context: Runtime ``LambdaContext``.
    ///
    /// - Returns: A Lambda result ot type `Output`.
    func handle(_ event: Event, context: LambdaContext) async throws -> Output
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension LambdaHandler {
    public init(context: LambdaInitializationContext) async throws {
        try await self.init()
    }
    
    public static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self> {
        let promise = context.eventLoop.makePromise(of: Self.self)
        promise.completeWithTask {
            try await Self(context: context)
        }
        return promise.futureResult
    }

    public func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Output> {
        let promise = context.eventLoop.makePromise(of: Output.self)
        // using an unchecked sendable wrapper for the handler
        // this is safe since lambda runtime is designed to calls the handler serially
        let handler = UncheckedSendableHandler(underlying: self)
        promise.completeWithTask {
            try await handler.handle(event, context: context)
        }
        return promise.futureResult
    }
}

/// unchecked sendable wrapper for the handler
/// this is safe since lambda runtime is designed to calls the handler serially
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
fileprivate struct UncheckedSendableHandler<Underlying: LambdaHandler, Event, Output>: @unchecked Sendable where Event == Underlying.Event, Output == Underlying.Output {
    let underlying: Underlying

    init(underlying: Underlying) {
        self.underlying = underlying
    }

    func handle(_ event: Event, context: LambdaContext) async throws -> Output {
        try await self.underlying.handle(event, context: context)
    }
}
#endif

// MARK: - EventLoopLambdaHandler

/// Strongly typed, `EventLoopFuture` based processing protocol for a Lambda that takes a user
/// defined ``Event`` and returns a user defined ``Output`` asynchronously.
///
/// ``EventLoopLambdaHandler`` extends ``ByteBufferLambdaHandler``, performing
/// `ByteBuffer` -> ``Event`` decoding and ``Output`` -> `ByteBuffer` encoding.
///
/// - note: To implement a Lambda, implement either ``LambdaHandler`` or the
///         ``EventLoopLambdaHandler`` protocol. The ``LambdaHandler`` will offload
///         the Lambda execution to an async Task making processing safer but slower (due to
///         fewer thread hops).
///         The ``EventLoopLambdaHandler`` will execute the Lambda on the same `EventLoop`
///         as the core runtime engine, making the processing faster but requires more care from the
///         implementation to never block the `EventLoop`. Implement this protocol only in performance
///         critical situations and implement ``LambdaHandler`` in all other circumstances.
public protocol EventLoopLambdaHandler: ByteBufferLambdaHandler {
    /// The lambda functions input. In most cases this should be `Codable`. If your event originates from an
    /// AWS service, have a look at [AWSLambdaEvents](https://github.com/swift-server/swift-aws-lambda-events),
    /// which provides a number of commonly used AWS Event implementations.
    associatedtype Event
    /// The lambda functions output. Can be `Void`.
    associatedtype Output

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime ``LambdaContext``.
    ///     - event: Event of type `Event` representing the event or request.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response of type ``Output`` or an `Error`.
    func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Output>

    /// Encode a response of type ``Output`` to `ByteBuffer`.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///     - allocator: A `ByteBufferAllocator` to help allocate the `ByteBuffer`.
    ///     - value: Response of type ``Output``.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(allocator: ByteBufferAllocator, value: Output) throws -> ByteBuffer?

    /// Decode a `ByteBuffer` to a request or event of type ``Event``.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type ``Event``.
    func decode(buffer: ByteBuffer) throws -> Event
}

extension EventLoopLambdaHandler {
    /// Driver for `ByteBuffer` -> ``Event`` decoding and ``Output`` -> `ByteBuffer` encoding
    @inlinable
    public func handle(_ event: ByteBuffer, context: LambdaContext) -> EventLoopFuture<ByteBuffer?> {
        let input: Event
        do {
            input = try self.decode(buffer: event)
        } catch {
            return context.eventLoop.makeFailedFuture(CodecError.requestDecoding(error))
        }

        return self.handle(input, context: context).flatMapThrowing { output in
            do {
                return try self.encode(allocator: context.allocator, value: output)
            } catch {
                throw CodecError.responseEncoding(error)
            }
        }
    }
}

/// Implementation of  `ByteBuffer` to `Void` decoding.
extension EventLoopLambdaHandler where Output == Void {
    @inlinable
    public func encode(allocator: ByteBufferAllocator, value: Void) throws -> ByteBuffer? {
        nil
    }
}

// MARK: - ByteBufferLambdaHandler

/// An `EventLoopFuture` based processing protocol for a Lambda that takes a `ByteBuffer` and returns
/// an optional `ByteBuffer` asynchronously.
///
/// - note: This is a low level protocol designed to power the higher level ``EventLoopLambdaHandler`` and
///         ``LambdaHandler`` based APIs.
///         Most users are not expected to use this protocol.
public protocol ByteBufferLambdaHandler {
    #if DEBUG
    /// Informs the Lambda whether or not it should run as a local server.
    ///
    /// If not implemented, this variable has a default value that follows this priority:
    ///
    /// 1. The value of the `LOCAL_LAMBDA_SERVER_ENABLED` environment variable.
    /// 2. If the env variable isn't found, defaults to `true` if running directly in Xcode.
    /// 3. If not running in Xcode and the env variable is missing, defaults to `false`.
    /// 4. No-op on `RELEASE` (production) builds. The AWSLambdaRuntime framework will not compile
    /// any logic accessing this property.
    ///
    /// The following is an example of this variable within a simple ``LambdaHandler`` that uses
    /// `Codable` types for its associated `Event` and `Output` types:
    ///
    /// ```swift
    /// import AWSLambdaRuntime
    /// import Foundation
    ///
    /// @main
    /// struct EntryHandler: LambdaHandler {
    ///     static let isLocalServer = true
    ///
    ///     func handle(_ event: Event, context: LambdaContext) async throws -> Output {
    ///         try await client.processResponse(for: event)
    ///     }
    /// }
    /// ```
    static var isLocalServer: Bool { get }
    #endif
    
    /// Create your Lambda handler for the runtime.
    ///
    /// Use this to initialize all your resources that you want to cache between invocations. This could be database
    /// connections and HTTP clients for example. It is encouraged to use the given `EventLoop`'s conformance
    /// to `EventLoopGroup` when initializing NIO dependencies. This will improve overall performance, as it
    /// minimizes thread hopping.
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self>

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime ``LambdaContext``.
    ///     - event: The event or input payload encoded as `ByteBuffer`.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response encoded as `ByteBuffer` or an `Error`.
    func handle(_ event: ByteBuffer, context: LambdaContext) -> EventLoopFuture<ByteBuffer?>
}

extension ByteBufferLambdaHandler {
    #if DEBUG
    /// If running this Lambda in Xcode, this value defaults to `true` if the presence of the
    /// `LOCAL_LAMBDA_SERVER_ENABLED` environment variable cannot be found. Otherwise, this value
    /// defaults to `false`.
    public static var isLocalServer: Bool {
        var enabled = Lambda.env("LOCAL_LAMBDA_SERVER_ENABLED").flatMap(Bool.init)
        
        #if Xcode
        if enabled == nil {
            enabled = true
        }
        #endif
        
        return enabled ?? false
    }
    #endif
    
    /// Initializes and runs the Lambda function.
    ///
    /// If you precede your ``ByteBufferLambdaHandler`` conformer's declaration with the
    /// [@main](https://docs.swift.org/swift-book/ReferenceManual/Attributes.html#ID626)
    /// attribute, the system calls the conformer's `main()` method to launch the lambda function.
    ///
    /// The lambda runtime provides a default implementation of the method that manages the launch
    /// process.
    public static func main() throws {
        try Lambda.run(configuration: .init(), handlerType: Self.self)
    }
}

@usableFromInline
enum CodecError: Error {
    case requestDecoding(Error)
    case responseEncoding(Error)
}
