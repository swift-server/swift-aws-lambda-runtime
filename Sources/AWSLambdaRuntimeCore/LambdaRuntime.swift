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
import Logging
import NIOConcurrencyHelpers
import NIOCore

// We need `@unchecked` Sendable here, as `NIOLockedValueBox` does not understand `sending` today.
// We don't want to use `NIOLockedValueBox` here anyway. We would love to use Mutex here, but this
// sadly crashes the compiler today.
public final class LambdaRuntime<Handler>: @unchecked Sendable where Handler: StreamingLambdaHandler {
    // TODO: We want to change this to Mutex as soon as this doesn't crash the Swift compiler on Linux anymore
    let handlerMutex: NIOLockedValueBox<Handler?>
    let logger: Logger
    let eventLoop: EventLoop

    public init(
        handler: sending Handler,
        eventLoop: EventLoop = Lambda.defaultEventLoop,
        logger: Logger = Logger(label: "LambdaRuntime")
    ) {
        self.handlerMutex = NIOLockedValueBox(handler)
        self.eventLoop = eventLoop

        // by setting the log level here, we understand it can not be changed dynamically at runtime
        // developers have to wait for AWS Lambda to dispose and recreate a runtime environment to pickup a change
        // this approach is less flexible but more performant than reading the value of the environment variable at each invocation
        var log = logger
        log.logLevel = Lambda.env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info        
        self.logger = logger
    }

    public func run() async throws {
        guard let runtimeEndpoint = Lambda.env("AWS_LAMBDA_RUNTIME_API") else {
            throw LambdaRuntimeError(code: .missingLambdaRuntimeAPIEnvironmentVariable)
        }

        let ipAndPort = runtimeEndpoint.split(separator: ":", maxSplits: 1)
        let ip = String(ipAndPort[0])
        guard let port = Int(ipAndPort[1]) else { throw LambdaRuntimeError(code: .invalidPort) }

        let handler = self.handlerMutex.withLockedValue { handler in
            let result = handler
            handler = nil
            return result
        }

        guard let handler else {
            throw LambdaRuntimeError(code: .runtimeCanOnlyBeStartedOnce)
        }

        try await LambdaRuntimeClient.withRuntimeClient(
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
