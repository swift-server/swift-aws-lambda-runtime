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

#if swift(<5.9)
import Backtrace
#endif
import Logging
import NIOCore
import NIOPosix

public enum Lambda {
    /// Run a Lambda defined by implementing the ``SimpleLambdaHandler`` protocol.
    /// The Runtime will manage the Lambdas application lifecycle automatically.
    ///
    /// - parameters:
    ///     - configuration: A Lambda runtime configuration object
    ///     - handlerType: The Handler to create and invoke.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    internal static func run<Handler: SimpleLambdaHandler>(
        configuration: LambdaConfiguration = .init(),
        handlerType: Handler.Type
    ) -> Result<Int, Error> {
        Self.run(configuration: configuration, handlerProvider: CodableSimpleLambdaHandler<Handler>.makeHandler(context:))
    }

    /// Run a Lambda defined by implementing the ``LambdaHandler`` protocol.
    /// The Runtime will manage the Lambdas application lifecycle automatically. It will invoke the
    /// ``LambdaHandler/makeHandler(context:)`` to create a new Handler.
    ///
    /// - parameters:
    ///     - configuration: A Lambda runtime configuration object
    ///     - handlerType: The Handler to create and invoke.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    internal static func run<Handler: LambdaHandler>(
        configuration: LambdaConfiguration = .init(),
        handlerType: Handler.Type
    ) -> Result<Int, Error> {
        Self.run(configuration: configuration, handlerProvider: CodableLambdaHandler<Handler>.makeHandler(context:))
    }

    /// Run a Lambda defined by implementing the ``EventLoopLambdaHandler`` protocol.
    /// The Runtime will manage the Lambdas application lifecycle automatically. It will invoke the
    /// ``EventLoopLambdaHandler/makeHandler(context:)`` to create a new Handler.
    ///
    /// - parameters:
    ///     - configuration: A Lambda runtime configuration object
    ///     - handlerType: The Handler to create and invoke.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    internal static func run<Handler: EventLoopLambdaHandler>(
        configuration: LambdaConfiguration = .init(),
        handlerType: Handler.Type
    ) -> Result<Int, Error> {
        Self.run(configuration: configuration, handlerProvider: CodableEventLoopLambdaHandler<Handler>.makeHandler(context:))
    }

    /// Run a Lambda defined by implementing the ``ByteBufferLambdaHandler`` protocol.
    /// The Runtime will manage the Lambdas application lifecycle automatically. It will invoke the
    /// ``ByteBufferLambdaHandler/makeHandler(context:)`` to create a new Handler.
    ///
    /// - parameters:
    ///     - configuration: A Lambda runtime configuration object
    ///     - handlerType: The Handler to create and invoke.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    internal static func run(
        configuration: LambdaConfiguration = .init(),
        handlerType: (some ByteBufferLambdaHandler).Type
    ) -> Result<Int, Error> {
        Self.run(configuration: configuration, handlerProvider: handlerType.makeHandler(context:))
    }

    /// Run a Lambda defined by implementing the ``LambdaRuntimeHandler`` protocol.
    /// - parameters:
    ///     - configuration: A Lambda runtime configuration object
    ///     - handlerProvider: A provider of the ``LambdaRuntimeHandler`` to invoke.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    internal static func run(
        configuration: LambdaConfiguration = .init(),
        handlerProvider: @escaping (LambdaInitializationContext) -> EventLoopFuture<some LambdaRuntimeHandler>
    ) -> Result<Int, Error> {
        let _run = { (configuration: LambdaConfiguration) -> Result<Int, Error> in
            #if swift(<5.9)
            Backtrace.install()
            #endif
            var logger = Logger(label: "Lambda")
            logger.logLevel = configuration.general.logLevel

            var result: Result<Int, Error>!
            MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { eventLoop in
                let runtime = LambdaRuntime(
                    handlerProvider: handlerProvider,
                    eventLoop: eventLoop,
                    logger: logger,
                    configuration: configuration
                )
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
                return try Lambda.withLocalServer(invocationEndpoint: Lambda.env("LOCAL_LAMBDA_SERVER_INVOCATION_ENDPOINT")) {
                    _run(configuration)
                }
            } catch {
                return .failure(error)
            }
        } else {
            return _run(configuration)
        }
        #else
        return _run(configuration)
        #endif
    }
}

// MARK: - Public API

extension Lambda {
    /// Utility to access/read environment variables
    public static func env(_ name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(cString: value)
    }
}
