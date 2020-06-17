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
    /// A function that takes a `InitializationContext` and returns an `EventLoopFuture` of a `ByteBufferLambdaHandler`
    public typealias HandlerFactory = (InitializationContext) -> EventLoopFuture<Handler>

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
    public static func run(_ factory: @escaping (InitializationContext) throws -> Handler) {
        self.run(factory: factory)
    }

    /// Utility to access/read environment variables
    public static func env(_ name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(cString: value)
    }

    // for testing and internal use
    @discardableResult
    internal static func run(configuration: Configuration = .init(), handler: Handler) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { $0.eventLoop.makeSucceededFuture(handler) })
    }

    // for testing and internal use
    @discardableResult
    internal static func run(configuration: Configuration = .init(), factory: @escaping (InitializationContext) throws -> Handler) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { context -> EventLoopFuture<Handler> in
            let promise = context.eventLoop.makePromise(of: Handler.self)
            // if we have a callback based handler factory, we offload the creation of the handler
            // onto the default offload queue, to ensure that the eventloop is never blocked.
            Lambda.defaultOffloadQueue.async {
                do {
                    promise.succeed(try factory(context))
                } catch {
                    promise.fail(error)
                }
            }
            return promise.futureResult
        })
    }

    // for testing and internal use
    @discardableResult
    internal static func run(configuration: Configuration = .init(), factory: @escaping HandlerFactory) -> Result<Int, Error> {
        let _run = { (configuration: Configuration, factory: @escaping HandlerFactory) -> Result<Int, Error> in
            Backtrace.install()
            var logger = Logger(label: "Lambda")
            logger.logLevel = configuration.general.logLevel

            var result: Result<Int, Error>!
            MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { eventLoop in
                let lifecycle = Lifecycle(eventLoop: eventLoop, logger: logger, configuration: configuration, factory: factory)
                #if DEBUG
                let signalSource = trap(signal: configuration.lifecycle.stopSignal) { signal in
                    logger.info("intercepted signal: \(signal)")
                    lifecycle.shutdown()
                }
                #endif

                lifecycle.start().flatMap {
                    lifecycle.shutdownFuture
                }.whenComplete { lifecycleResult in
                    #if DEBUG
                    signalSource.cancel()
                    #endif
                    eventLoop.shutdownGracefully { error in
                        if let error = error {
                            preconditionFailure("Failed to shutdown eventloop: \(error)")
                        }
                    }
                    result = lifecycleResult
                }
            }

            logger.info("shutdown completed")
            return result
        }

        // start local server for debugging in DEBUG mode only
        #if DEBUG
        if Lambda.env("LOCAL_LAMBDA_SERVER_ENABLED").flatMap(Bool.init) ?? false {
            do {
                return try Lambda.withLocalServer {
                    _run(configuration, factory)
                }
            } catch {
                return .failure(error)
            }
        } else {
            return _run(configuration, factory)
        }
        #else
        return _run(configuration, factory)
        #endif
    }
}
