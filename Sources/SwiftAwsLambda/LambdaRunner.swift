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
    private let eventLoopGroup: EventLoopGroup

    init(eventLoopGroup: EventLoopGroup, lambdaHandler: LambdaHandler) {
        self.eventLoopGroup = eventLoopGroup
        self.runtimeClient = LambdaRuntimeClient(eventLoopGroup: self.eventLoopGroup)
        self.lambdaHandler = lambdaHandler
    }

    /// Run the user provided initializer. This *must* only be called once.
    ///
    /// - Returns: An `EventLoopFuture<Void>` fulfilled with the outcome of the initialization.
    func initialize(logger: Logger) -> EventLoopFuture<Void> {
        let initPromise = self.eventLoopGroup.next().makePromise(of: Void.self)
        self.lambdaHandler.initialize(promise: initPromise)

        // We need to use `flatMap` instead of `whenFailure` to ensure we complete reporting the result before stopping.
        return initPromise.futureResult.flatMapError { error in
            self.runtimeClient.reportInitError(logger: logger, error: error).flatMapResult { postResult -> Result<Void, Error> in
                switch postResult {
                case .failure(let postResultError):
                    // We're going to bail out because the init failed, so there's not a lot we can do other than log
                    // that we couldn't report this error back to the runtime.
                    logger.error("could not report initialization error to lambda runtime engine: \(postResultError)")
                case .success:
                    logger.info("successfully reported initialization error")
                }
                // Always return the init error
                return .failure(error)
            }
        }
    }

    func run(logger: Logger) -> EventLoopFuture<LambdaRunResult> {
        var logger = logger
        logger.info("lambda invocation sequence starting")
        // 1. request work from lambda runtime engine
        return self.runtimeClient.requestWork(logger: logger).flatMap { workRequestResult in
            switch workRequestResult {
            case .failure(let error):
                logger.error("could not fetch work from lambda runtime engine: \(error)")
                return self.makeSucceededFuture(result: .failure(error))
            case .success(let context, let payload):
                logger[metadataKey: "awsRequestId"] = .string(context.requestId)
                if let traceId = context.traceId {
                    logger[metadataKey: "awsTraceId"] = .string(traceId)
                }
                // 2. send work to handler
                logger.info("sending work to lambda handler \(self.lambdaHandler)")
                let promise = self.eventLoopGroup.next().makePromise(of: LambdaResult.self)
                self.lambdaHandler.handle(context: context, payload: payload, promise: promise)
                return promise.futureResult.flatMap { lambdaResult in
                    // 3. report results to runtime engine
                    self.runtimeClient.reportResults(logger: logger, context: context, result: lambdaResult).flatMap { postResultsResult in
                        switch postResultsResult {
                        case .failure(let error):
                            logger.error("could not report results to lambda runtime engine: \(error)")
                            return self.makeSucceededFuture(result: .failure(error))
                        case .success():
                            // we are done!
                            logger.info("lambda invocation sequence completed successfully")
                            return self.makeSucceededFuture(result: .success(()))
                        }
                    }
                }
            }
        }
    }

    private func makeSucceededFuture<T>(result: T) -> EventLoopFuture<T> {
        return self.eventLoopGroup.next().makeSucceededFuture(result)
    }
}

internal typealias LambdaRunResult = Result<Void, Error>

private extension LambdaHandler {
    func handle(context: LambdaContext, payload: [UInt8], promise: EventLoopPromise<LambdaResult>) {
        // offloading so user code never blocks the eventloop
        DispatchQueue(label: "lambda-\(context.requestId)").async {
            self.handle(context: context, payload: payload) { (result: LambdaResult) in
                promise.succeed(result)
            }
        }
    }

    func initialize(promise: EventLoopPromise<Void>) {
        // offloading so user code never blocks the eventloop
        DispatchQueue(label: "lambda-initialize").async {
            self.initialize { result in
                switch result {
                case .failure(let error):
                    return promise.fail(error)
                case .success:
                    return promise.succeed(())
                }
            }
        }
    }
}
