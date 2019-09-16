//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import NIO

/// LambdaRunner manages the Lambda runtime workflow, or business logic.
internal final class LambdaRunner {
    private let runtimeClient: LambdaRuntimeClient
    private let lambdaHandler: LambdaHandler
    private let eventLoop: EventLoop
    private let lifecycleId: String

    init(eventLoop: EventLoop, lambdaHandler: LambdaHandler, lifecycleId: String) {
        self.eventLoop = eventLoop
        self.runtimeClient = LambdaRuntimeClient(eventLoop: self.eventLoop)
        self.lambdaHandler = lambdaHandler
        self.lifecycleId = lifecycleId
    }

    /// Run the user provided initializer. This *must* only be called once.
    ///
    /// - Returns: An `EventLoopFuture<Void>` fulfilled with the outcome of the initialization.
    func initialize(logger: Logger) -> EventLoopFuture<Void> {
        logger.info("initializing lambda")
        // We need to use `flatMap` instead of `whenFailure` to ensure we complete reporting the result before stopping.
        return self.lambdaHandler.initialize(eventLoop: self.eventLoop, lifecycleId: self.lifecycleId).flatMapError { error in
            self.runtimeClient.reportInitializationError(logger: logger, error: error).flatMapResult { result -> Result<Void, Error> in
                if case .failure(let reportingError) = result {
                    // We're going to bail out because the init failed, so there's not a lot we can do other than log
                    // that we couldn't report this error back to the runtime.
                    logger.error("failed reporting initialization error to lambda runtime engine: \(reportingError)")
                }
                // Always return the init error
                return .failure(error)
            }
        }
    }

    func run(logger: Logger) -> EventLoopFuture<Void> {
        logger.info("lambda invocation sequence starting")
        // 1. request work from lambda runtime engine
        return self.runtimeClient.requestWork(logger: logger).flatMap { workRequestResult in
            switch workRequestResult {
            case .failure(let error):
                logger.error("could not fetch work from lambda runtime engine: \(error)")
                return self.eventLoop.makeFailedFuture(error)
            case .success(let context, let payload):
                // 2. send work to handler
                logger.info("sending work to lambda handler \(self.lambdaHandler)")
                return self.lambdaHandler.handle(eventLoop: self.eventLoop, lifecycleId: self.lifecycleId, context: context, payload: payload).flatMap { lambdaResult in
                    // 3. report results to runtime engine
                    self.runtimeClient.reportResults(logger: logger, context: context, result: lambdaResult).flatMap { postResultsResult in
                        switch postResultsResult {
                        case .failure(let error):
                            logger.error("failed reporting results to lambda runtime engine: \(error)")
                            return self.eventLoop.makeFailedFuture(error)
                        case .success():
                            // we are done!
                            logger.info("lambda invocation sequence completed successfully")
                            return self.eventLoop.makeSucceededFuture(())
                        }
                    }
                }
            }
        }
    }
}

private extension LambdaHandler {
    func initialize(eventLoop: EventLoop, lifecycleId: String) -> EventLoopFuture<Void> {
        // offloading so user code never blocks the eventloop
        let promise = eventLoop.makePromise(of: Void.self)
        DispatchQueue(label: "lambda-\(lifecycleId)").async {
            self.initialize { promise.completeWith($0) }
        }
        return promise.futureResult
    }

    func handle(eventLoop: EventLoop, lifecycleId: String, context: LambdaContext, payload: [UInt8]) -> EventLoopFuture<LambdaResult> {
        // offloading so user code never blocks the eventloop
        let promise = eventLoop.makePromise(of: LambdaResult.self)
        DispatchQueue(label: "lambda-\(lifecycleId)").async {
            self.handle(context: context, payload: payload) { result in
                promise.succeed(result)
            }
        }
        return promise.futureResult
    }
}
