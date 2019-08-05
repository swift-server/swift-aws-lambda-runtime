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
}
