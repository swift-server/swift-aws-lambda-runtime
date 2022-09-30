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
    /// Run a Lambda defined by implementing the ``ByteBufferLambdaHandler`` protocol.
    /// The Runtime will manage the Lambdas application lifecycle automatically. It will invoke the
    /// ``ByteBufferLambdaHandler/makeHandler(context:)`` to create a new Handler.
    ///
    /// - parameters:
    ///     - configuration: A Lambda runtime configuration object
    ///     - handlerType: The Handler to create and invoke.
    ///
    /// - note: This is a blocking operation that will run forever, as its lifecycle is managed by the AWS Lambda Runtime Engine.
    @discardableResult
    internal static func run<Handler: ByteBufferLambdaHandler>(
        configuration: LambdaConfiguration = .init(),
        handlerType: Handler.Type
    ) throws -> Int {
        var result: Result<Int, Error> = .success(0)
        
        // start local server for debugging in DEBUG mode only
        #if DEBUG
        var localServer: LocalLambda.Server? = nil
        if Handler.isLocalServer {
            localServer = try Lambda.startLocalServer()
        }
        #endif

        Backtrace.install()
        var logger = Logger(label: "Lambda")
        logger.logLevel = configuration.general.logLevel

        MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { eventLoop in
            let runtime = LambdaRuntime<Handler>(eventLoop: eventLoop, logger: logger, configuration: configuration)
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
        
        #if DEBUG
        try localServer?.stop()
        #endif
        
        switch result {
        case .success(let count):
            return count
        case .failure(let error):
            throw error
        }
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
