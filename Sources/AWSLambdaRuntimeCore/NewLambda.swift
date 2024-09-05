//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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

extension Lambda {
    package static func runLoop<RuntimeClient: LambdaRuntimeClientProtocol, Handler>(
        runtimeClient: RuntimeClient,
        handler: Handler,
        logger: Logger
    ) async throws where Handler: StreamingLambdaHandler {
        var handler = handler

        while !Task.isCancelled {
            let (invocation, writer) = try await runtimeClient.nextInvocation()

            do {
                try await handler.handle(
                    invocation.event,
                    responseWriter: writer,
                    context: NewLambdaContext(
                        requestID: invocation.metadata.requestID,
                        traceID: invocation.metadata.traceID,
                        invokedFunctionARN: invocation.metadata.invokedFunctionARN,
                        deadline: DispatchWallTime(millisSinceEpoch: invocation.metadata.deadlineInMillisSinceEpoch),
                        logger: logger
                    )
                )
            } catch {
                try await writer.reportError(error)
                continue
            }
        }
    }

    /// The default EventLoop the Lambda is scheduled on.
    package static var defaultEventLoop: any EventLoop = NIOSingletons.posixEventLoopGroup.next()
}
