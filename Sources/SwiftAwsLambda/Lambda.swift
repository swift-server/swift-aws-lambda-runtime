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
    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ handler: ByteBufferLambdaHandler) {
        self.run(handler: handler)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol provided via a `LambdaHandlerFactory`.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ factory: @escaping LambdaHandlerFactory) {
        self.run(factory: factory)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol provided via a factory, typically a constructor.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ factory: @escaping (EventLoop) throws -> ByteBufferLambdaHandler) {
        self.run(factory: factory)
    }

    // for testing and internal use
    @discardableResult
    internal static func run(configuration: Configuration = .init(), handler: ByteBufferLambdaHandler) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { $0.makeSucceededFuture(handler) })
    }

    // for testing and internal use
    @discardableResult
    internal static func run(configuration: Configuration = .init(), factory: @escaping (EventLoop) throws -> ByteBufferLambdaHandler) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { eventloop -> EventLoopFuture<ByteBufferLambdaHandler> in
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
    internal static func run(configuration: Configuration = .init(), factory: @escaping LambdaHandlerFactory) -> Result<Int, Error> {
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

public typealias LambdaHandlerFactory = (EventLoop) -> EventLoopFuture<ByteBufferLambdaHandler>
