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

import Dispatch // for offloading
import Logging
import NIO

internal extension Lambda {
    /// LambdaRunner manages the Lambda runtime workflow, or business logic.
    struct Runner {
        private let runtimeClient: RuntimeClient
        private let provider: (EventLoop) throws -> LambdaHandler
        private let eventLoop: EventLoop
        private let lifecycleId: String
        private let offload: Bool

        init(eventLoop: EventLoop, configuration: Configuration, provider: @escaping (EventLoop) throws -> LambdaHandler) {
            self.eventLoop = eventLoop
            self.runtimeClient = RuntimeClient(eventLoop: self.eventLoop, configuration: configuration.runtimeEngine)
            self.provider = provider
            self.lifecycleId = configuration.lifecycle.id
            self.offload = configuration.runtimeEngine.offload
        }

        /// Run the user provided initializer. This *must* only be called once.
        ///
        /// - Returns: An `EventLoopFuture<Void>` fulfilled with the outcome of the initialization.
        func initialize(logger: Logger) -> EventLoopFuture<LambdaHandler> {
            let future: EventLoopFuture<LambdaHandler>
            do {
                let handler = try self.provider(self.eventLoop)
                if let handler = handler as? BootstrappedLambdaHandler {
                    logger.debug("bootstrapping lambda")
                    future = handler.bootstrap(eventLoop: self.eventLoop, lifecycleId: self.lifecycleId, offload: self.offload).map { handler }
                } else {
                    future = self.eventLoop.makeSucceededFuture(handler)
                }

            } catch {
                future = self.eventLoop.makeFailedFuture(error)
            }
            return future.peekError { error in
                self.runtimeClient.reportInitializationError(logger: logger, error: error).peekError { reportingError in
                    // We're going to bail out because the init failed, so there's not a lot we can do other than log
                    // that we couldn't report this error back to the runtime.
                    logger.error("failed reporting initialization error to lambda runtime engine: \(reportingError)")
                }
            }
        }

        func run(logger: Logger, handler: LambdaHandler) -> EventLoopFuture<Void> {
            logger.debug("lambda invocation sequence starting")
            // 1. request work from lambda runtime engine
            return self.runtimeClient.requestWork(logger: logger).peekError { error in
                logger.error("could not fetch work from lambda runtime engine: \(error)")
            }.flatMap { context, payload in
                // 2. send work to handler
                logger.debug("sending work to lambda handler \(handler)")
                return handler.handle(eventLoop: self.eventLoop,
                                      lifecycleId: self.lifecycleId,
                                      offload: self.offload,
                                      context: context,
                                      payload: payload).mapResult { (context, $0) }
            }.flatMap { context, result in
                // 3. report results to runtime engine
                self.runtimeClient.reportResults(logger: logger, context: context, result: result).peekError { error in
                    logger.error("failed reporting results to lambda runtime engine: \(error)")
                }
            }.always { result in
                // we are done!
                logger.log(level: result.successful ? .info : .warning, "lambda invocation sequence completed \(result.successful ? "successfully" : "with failure")")
            }
        }
    }
}

private extension BootstrappedLambdaHandler {
    func bootstrap(eventLoop: EventLoop, lifecycleId: String, offload: Bool) -> EventLoopFuture<Void> {
        // offloading so user code never blocks the eventloop
        let promise = eventLoop.makePromise(of: Void.self)
        /* if offload {
             DispatchQueue(label: "lambda-\(lifecycleId)").async {
                 self.initialize { promise.completeWith($0) }
             }
         } else {
             self.initialize { promise.completeWith($0) }
         }
         return promise.futureResult */
        // FIXME: offloading
        self.bootstrap(eventLoop: eventLoop, promise: promise)
        return promise.futureResult
    }
}

private extension LambdaHandler {
    func handle(eventLoop: EventLoop, lifecycleId: String, offload: Bool, context: Lambda.Context, payload: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
        // offloading so user code never blocks the eventloop
        let promise = eventLoop.makePromise(of: ByteBuffer?.self)
        /* if offload {
             DispatchQueue(label: "lambda-\(lifecycleId)").async {
                 self.handle(context: context, payload: payload) { result in
                     promise.succeed(result)
                 }
             }
         } else {
             self.handle(context: context, payload: payload) { result in
                 promise.succeed(result)
             }
         }
         return promise.futureResult */

        // FIXME: offloading
        self.handle(context: context, payload: payload, promise: promise)
        return promise.futureResult
    }
}

// TODO: move to nio?
private extension EventLoopFuture {
    // callback does not have side effects, failing with original result
    func peekError(_ callback: @escaping (Error) -> Void) -> EventLoopFuture<Value> {
        return self.flatMapError { error in
            callback(error)
            return self
        }
    }

    // callback does not have side effects, failing with original result
    func peekError(_ callback: @escaping (Error) -> EventLoopFuture<Void>) -> EventLoopFuture<Value> {
        return self.flatMapError { error in
            let promise = self.eventLoop.makePromise(of: Value.self)
            callback(error).whenComplete { _ in
                promise.completeWith(self)
            }
            return promise.futureResult
        }
    }

    func mapResult<NewValue>(_ callback: @escaping (Result<Value, Error>) -> NewValue) -> EventLoopFuture<NewValue> {
        return self.map { value in
            callback(.success(value))
        }.flatMapErrorThrowing { error in
            callback(.failure(error))
        }
    }
}

private extension Result {
    var successful: Bool {
        switch self {
        case .success:
            return true
        default:
            return false
        }
    }
}
