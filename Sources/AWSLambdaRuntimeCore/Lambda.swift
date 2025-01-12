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

import Dispatch
import Logging
import NIOCore
import NIOPosix
import Synchronization

#if os(macOS)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
#error("Unsupported platform")
#endif

public enum Lambda {

    // allow to gracefully shitdown the runtime client loop
    // this supports gracefull shutdown of the Lambda runtime when integarted with Swift ServiceLifeCycle
    private static let gracefulShutdown: Mutex<Bool> = Mutex(false)
    public static func shutdown() {
        Lambda.gracefulShutdown.withLock {
            $0 = true
        }
    }
    package static func runLoop<RuntimeClient: LambdaRuntimeClientProtocol, Handler>(
        runtimeClient: RuntimeClient,
        handler: Handler,
        logger: Logger
    ) async throws where Handler: StreamingLambdaHandler {
        var handler = handler
        var gracefulShutdown: Bool = Lambda.gracefulShutdown.withLock { $0 }
        do {
            while !Task.isCancelled && !gracefulShutdown {
                logger.trace("Waiting for next invocation")
                let (invocation, writer) = try await runtimeClient.nextInvocation()

                logger.trace("Received invocation : \(invocation.metadata.requestID)")
                do {
                    try await handler.handle(
                        invocation.event,
                        responseWriter: writer,
                        context: LambdaContext(
                            requestID: invocation.metadata.requestID,
                            traceID: invocation.metadata.traceID,
                            invokedFunctionARN: invocation.metadata.invokedFunctionARN,
                            deadline: DispatchWallTime(
                                millisSinceEpoch: invocation.metadata.deadlineInMillisSinceEpoch
                            ),
                            logger: logger
                        )
                    )
                } catch {
                    try await writer.reportError(error)
                    continue
                }
                logger.trace("Completed invocation : \(invocation.metadata.requestID)")
                gracefulShutdown = Lambda.gracefulShutdown.withLock { $0 }
            }

        } catch is CancellationError {
            // don't allow cancellation error to propagate further
            logger.trace("Lambda runLoop() task has been cancelled")
        }
        logger.trace("Lambda runLoop() terminated \(gracefulShutdown ? "with gracefull shutdown" : "")")
    }

    /// The default EventLoop the Lambda is scheduled on.
    public static let defaultEventLoop: any EventLoop = NIOSingletons.posixEventLoopGroup.next()
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
