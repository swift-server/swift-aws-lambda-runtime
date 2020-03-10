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

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Backtrace
import Logging
import NIO

public enum Lambda {
    /// Run a Lambda defined by implementing the `LambdaClosure` closure.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ closure: @escaping LambdaClosure) {
        self.run(closure: closure)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ handler: LambdaHandler) {
        self.run(handler: handler)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol via a `LambdaHandlerFactory`.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ factory: @escaping LambdaHandlerFactory) {
        self.run(factory: factory)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol via a factory.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ factory: @escaping (EventLoop) throws -> LambdaHandler) {
        self.run(factory: factory)
    }

    // for testing and internal use
    @usableFromInline
    @discardableResult
    internal static func run(configuration: Configuration = .init(), closure: @escaping LambdaClosure) -> LambdaLifecycleResult {
        return self.run(configuration: configuration, handler: LambdaClosureWrapper(closure))
    }

    // for testing and internal use
    @usableFromInline
    @discardableResult
    internal static func run(configuration: Configuration = .init(), handler: LambdaHandler) -> LambdaLifecycleResult {
        return self.run(configuration: configuration, factory: { _, callback in callback(.success(handler)) })
    }

    // for testing and internal use
    @usableFromInline
    @discardableResult
    internal static func run(configuration: Configuration = .init(), factory: @escaping (EventLoop) throws -> LambdaHandler) -> LambdaLifecycleResult {
        return self.run(configuration: configuration, factory: { (eventloop: EventLoop, callback: (Result<LambdaHandler, Error>) -> Void) -> Void in
            do {
                let handler = try factory(eventloop)
                callback(.success(handler))
            } catch {
                callback(.failure(error))
            }
        })
    }

    // for testing and internal use
    @usableFromInline
    @discardableResult
    internal static func run(configuration: Configuration = .init(), factory: @escaping LambdaHandlerFactory) -> LambdaLifecycleResult {
        do {
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1) // only need one thread, will improve performance
            defer { try! eventLoopGroup.syncShutdownGracefully() }
            let result = try self.runAsync(eventLoopGroup: eventLoopGroup, configuration: configuration, factory: factory).wait()
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    internal static func runAsync(eventLoopGroup: EventLoopGroup, configuration: Configuration, factory: @escaping LambdaHandlerFactory) -> EventLoopFuture<Int> {
        Backtrace.install()
        var logger = Logger(label: "Lambda")
        logger.logLevel = configuration.general.logLevel
        let lifecycle = Lifecycle(eventLoop: eventLoopGroup.next(), logger: logger, configuration: configuration, factory: factory)
        let signalSource = trap(signal: configuration.lifecycle.stopSignal) { signal in
            logger.info("intercepted signal: \(signal)")
            lifecycle.stop()
        }
        return lifecycle.start().always { _ in
            lifecycle.shutdown()
            signalSource.cancel()
        }
    }
}

public typealias LambdaResult = Result<[UInt8], Error>

public typealias LambdaCallback = (LambdaResult) -> Void

/// A processing closure for a Lambda that takes a `[UInt8]` and returns a `LambdaResult` result type asynchronously via`LambdaCallback` .
public typealias LambdaClosure = (Lambda.Context, [UInt8], LambdaCallback) -> Void

/// A callback to provide the result of Lambda initialization.
public typealias LambdaInitCallBack = (Result<LambdaHandler, Error>) -> Void

public typealias LambdaHandlerFactory = (EventLoop, LambdaInitCallBack) -> Void

/// A processing protocol for a Lambda that takes a `[UInt8]` and returns a `LambdaResult` result type asynchronously via `LambdaCallback`.
public protocol LambdaHandler {
    /// Handles the Lambda request.
    func handle(context: Lambda.Context, payload: [UInt8], callback: @escaping LambdaCallback)
}

@usableFromInline
internal typealias LambdaLifecycleResult = Result<Int, Error>

private struct LambdaClosureWrapper: LambdaHandler {
    private let closure: LambdaClosure
    init(_ closure: @escaping LambdaClosure) {
        self.closure = closure
    }

    func handle(context: Lambda.Context, payload: [UInt8], callback: @escaping LambdaCallback) {
        self.closure(context, payload, callback)
    }
}
