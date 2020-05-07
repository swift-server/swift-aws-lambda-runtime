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

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Backtrace
import Logging
import NIO

public enum Lambda {
    public typealias Handler = ByteBufferLambdaHandler

    /// `ByteBufferLambdaHandler` factory.
    ///
    /// A function that takes a `EventLoop` and returns an `EventLoopFuture` of a `ByteBufferLambdaHandler`
    public typealias HandlerFactory = (EventLoop) -> EventLoopFuture<Handler>

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - parameters:
    ///     - handler: `ByteBufferLambdaHandler` based Lambda.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ handler: Handler) {
        self.run(handler: handler)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol provided via a `LambdaHandlerFactory`.
    /// Use this to initialize all your resources that you want to cache between invocations. This could be database connections and HTTP clients for example.
    /// It is encouraged to use the given `EventLoop`'s conformance to `EventLoopGroup` when initializing NIO dependencies. This will improve overall performance.
    ///
    /// - parameters:
    ///     - factory: A `ByteBufferLambdaHandler` factory.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ factory: @escaping HandlerFactory) {
        self.run(factory: factory)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol provided via a factory, typically a constructor.
    ///
    /// - parameters:
    ///     - factory: A `ByteBufferLambdaHandler` factory.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ factory: @escaping (EventLoop) throws -> Handler) {
        self.run(factory: factory)
    }

    // for testing and internal use
    @discardableResult
    public static func run(configuration: Configuration = .init(), handler: Handler) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { $0.makeSucceededFuture(handler) })
    }

    // for testing and internal use
    @discardableResult
    public static func run(configuration: Configuration = .init(), factory: @escaping (EventLoop) throws -> Handler) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { eventloop -> EventLoopFuture<Handler> in
            do {
                let handler = try factory(eventloop)
                return eventloop.makeSucceededFuture(handler)
            } catch {
                return eventloop.makeFailedFuture(error)
            }
        })
    }

    // for testing and internal use
    @discardableResult
    internal static func run(configuration: Configuration = .init(), factory: @escaping HandlerFactory) -> Result<Int, Error> {
        do {
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1) // only need one thread, will improve performance
            defer { try! eventLoopGroup.syncShutdownGracefully() }
            let result = try self.runAsync(eventLoopGroup: eventLoopGroup, configuration: configuration, factory: factory).wait()
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    internal static func runAsync(eventLoopGroup: EventLoopGroup, configuration: Configuration, factory: @escaping HandlerFactory) -> EventLoopFuture<Int> {
        Backtrace.install()
        var logger = Logger(label: "Lambda")
        logger.logLevel = configuration.general.logLevel
        let lifecycle = Lifecycle(eventLoop: eventLoopGroup.next(), logger: logger, configuration: configuration, factory: factory)
        let signalSource = trap(signal: configuration.lifecycle.stopSignal) { signal in
            logger.info("intercepted signal: \(signal)")
            lifecycle.shutdown()
        }
        return lifecycle.start().flatMap {
            return lifecycle.shutdownFuture.always { _ in
                signalSource.cancel()
            }
        }
    }
}
