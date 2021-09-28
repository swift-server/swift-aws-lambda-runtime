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
import NIOCore
import NIOPosix

public enum Lambda {
    public typealias Handler = ByteBufferLambdaHandler

    /// `ByteBufferLambdaHandler` factory.
    ///
    /// A function that takes a `InitializationContext` and returns an `EventLoopFuture` of a `ByteBufferLambdaHandler`
    public typealias HandlerFactory = (InitializationContext) -> EventLoopFuture<Handler>

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol provided via a `LambdaHandlerFactory`.
    /// Use this to initialize all your resources that you want to cache between invocations. This could be database connections and HTTP clients for example.
    /// It is encouraged to use the given `EventLoop`'s conformance to `EventLoopGroup` when initializing NIO dependencies. This will improve overall performance.
    ///
    /// - parameters:
    ///     - factory: A `ByteBufferLambdaHandler` factory.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ factory: @escaping HandlerFactory) {
        if case .failure(let error) = self.run(factory: factory) {
            fatalError("\(error)")
        }
    }

    /// Utility to access/read environment variables
    public static func env(_ name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(cString: value)
    }

    #if swift(>=5.5)
    // for testing and internal use
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    internal static func run<Handler: LambdaHandler>(configuration: Configuration = .init(), handlerType: Handler.Type) -> Result<Int, Error> {
        self.run(configuration: configuration, factory: { context -> EventLoopFuture<ByteBufferLambdaHandler> in
            let promise = context.eventLoop.makePromise(of: ByteBufferLambdaHandler.self)
            promise.completeWithTask {
                try await Handler(context: context)
            }
            return promise.futureResult
        })
    }
    #endif

    // for testing and internal use
    internal static func run(configuration: Configuration = .init(), factory: @escaping HandlerFactory) -> Result<Int, Error> {
        let _run = { (configuration: Configuration, factory: @escaping HandlerFactory) -> Result<Int, Error> in
            Backtrace.install()
            var logger = Logger(label: "Lambda")
            logger.logLevel = configuration.general.logLevel

            var result: Result<Int, Error>!
            MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { eventLoop in
                let runtime = LambdaRuntime(eventLoop: eventLoop, logger: logger, configuration: configuration, factory: factory)
                #if DEBUG
                let signalSource = trap(signal: configuration.lifecycle.stopSignal) { signal in
                    logger.info("intercepted signal: \(signal)")
                    runtime.shutdown()
                }
                #endif

                runtime.start().flatMap {
                    runtime.shutdownFuture
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
