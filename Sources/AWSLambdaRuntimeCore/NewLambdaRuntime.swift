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

import Foundation
//import ServiceLifecycle
import Logging
import NIOCore
import Synchronization

package final class NewLambdaRuntime<Handler>: Sendable where Handler: StreamingLambdaHandler {
    let handlerMutex: Mutex<Handler?>
    let logger: Logger
    let eventLoop: EventLoop

    package init(
        handler: sending Handler,
        eventLoop: EventLoop = Lambda.defaultEventLoop,
        logger: Logger = Logger(label: "LambdaRuntime")
    ) {
        self.handlerMutex = Mutex(handler)
        self.eventLoop = eventLoop
        self.logger = logger
    }

    package func run() async throws {
        guard let runtimeEndpoint = Lambda.env("AWS_LAMBDA_RUNTIME_API") else {
            throw NewLambdaRuntimeError(code: .cannotStartLambdaRuntime)
        }

        let ipAndPort = runtimeEndpoint.split(separator: ":", maxSplits: 1)
        let ip = String(ipAndPort[0])
        guard let port = Int(ipAndPort[1]) else { throw NewLambdaRuntimeError(code: .invalidPort) }

        let handler = self.handlerMutex.withLock { maybeHandler in
            defer {
                maybeHandler = nil
            }
            return maybeHandler
        }

        guard let handler else {
            throw NewLambdaRuntimeError(code: .runtimeCanOnlyBeStartedOnce)
        }

        try await NewLambdaRuntimeClient.withRuntimeClient(
            configuration: .init(ip: ip, port: port),
            eventLoop: self.eventLoop,
            logger: self.logger
        ) { runtimeClient in
            try await Lambda.runLoop(
                runtimeClient: runtimeClient,
                handler: handler,
                logger: self.logger
            )
        }
    }
}
