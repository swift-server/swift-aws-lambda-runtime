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

import AWSLambdaRuntimeCore
import Backtrace
import Logging
import NIO
#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// in this example we are receiving and responding with strings
struct Handler: EventLoopLambdaHandler {
    typealias In = String
    typealias Out = String

    func handle(context: Lambda.Context, event: String) -> EventLoopFuture<String> {
        // as an example, respond with the event's reversed body
        context.eventLoop.makeSucceededFuture(event)
    }
}

func run(factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>) {
    Backtrace.install()
    var logger = Logger(label: "Lambda")
    logger.logLevel = .info

    MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { eventLoop in
        let runtime = Lambda.Runtime(eventLoop: eventLoop, logger: logger, factory: factory)

        _ = runtime.start().whenSuccess { _ in
            _ = runtime.shutdownFuture?.always { _ in
                eventLoop.shutdownGracefully { _ in
                }
            }
        }
    }

    logger.info("shutdown completed")
}

run { $0.eventLoop.makeSucceededFuture(Handler()) }

// MARK: - this can also be expressed as a closure:

/*
 Lambda.run { (_, event: String, callback) in
   callback(.success(String(event.reversed())))
 }
 */
