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

import Logging
import NIOConcurrencyHelpers
import NIOCore
import Synchronization

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// This is our gardian to ensure only one LambdaRuntime is initialized
// We use a Mutex here to ensure thread safety
// We don't use LambdaRuntime<> as the type here, as we don't know the concrete type that will be used
private let _singleton = Mutex<Bool>(false)
public enum LambdaRuntimeError: Error {
    case moreThanOneLambdaRuntimeInstance
}
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
    ) throws(LambdaRuntimeError) {

        do {
            try _singleton.withLock {
                let alreadyCreated = $0
                guard alreadyCreated == false else {
                    throw LambdaRuntimeError.moreThanOneLambdaRuntimeInstance
                }
                $0 = true
            }
        } catch _ as LambdaRuntimeError {
            throw LambdaRuntimeError.moreThanOneLambdaRuntimeInstance
        } catch {
            fatalError("An unknown error occurred: \(error)")
        }

        self.handlerMutex = NIOLockedValueBox(handler)
        self.eventLoop = eventLoop

        // by setting the log level here, we understand it can not be changed dynamically at runtime
        // developers have to wait for AWS Lambda to dispose and recreate a runtime environment to pickup a change
        // this approach is less flexible but more performant than reading the value of the environment variable at each invocation
        var log = logger
        log.logLevel = Lambda.env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info
        self.logger = log
        self.logger.debug("LambdaRuntime initialized")
    }

    public func run() async throws {
        let handler = self.handlerMutex.withLockedValue { handler in
            let result = handler
            handler = nil
            return result
        }

        guard let handler else {
            throw LambdaRuntimeClientError(code: .runtimeCanOnlyBeStartedOnce)
        }

        // are we running inside an AWS Lambda runtime environment ?
        // AWS_LAMBDA_RUNTIME_API is set when running on Lambda
        // https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html
        if let runtimeEndpoint = Lambda.env("AWS_LAMBDA_RUNTIME_API") {

            let ipAndPort = runtimeEndpoint.split(separator: ":", maxSplits: 1)
            let ip = String(ipAndPort[0])
            guard let port = Int(ipAndPort[1]) else { throw LambdaRuntimeClientError(code: .invalidPort) }

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

        } else {

            #if LocalServerSupport
            // we're not running on Lambda and we're compiled in DEBUG mode,
            // let's start a local server for testing
            try await Lambda.withLocalServer(invocationEndpoint: Lambda.env("LOCAL_LAMBDA_SERVER_INVOCATION_ENDPOINT"))
            {

                try await LambdaRuntimeClient.withRuntimeClient(
                    configuration: .init(ip: "127.0.0.1", port: 7000),
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
            #else
            // in release mode, we can't start a local server because the local server code is not compiled.
            throw LambdaRuntimeError(code: .missingLambdaRuntimeAPIEnvironmentVariable)
            #endif
        }
    }
}
