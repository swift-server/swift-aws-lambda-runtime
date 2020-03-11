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

extension Lambda {
    /// LambdaRunner manages the Lambda runtime workflow, or business logic.
    internal struct Runner {
        private let runtimeClient: RuntimeClient
        private let eventLoop: EventLoop
        private let lifecycleId: String
        private let offload: Bool

        init(eventLoop: EventLoop, configuration: Configuration) {
            self.eventLoop = eventLoop
            self.runtimeClient = RuntimeClient(eventLoop: self.eventLoop, configuration: configuration.runtimeEngine)
            self.lifecycleId = configuration.lifecycle.id
            self.offload = configuration.runtimeEngine.offload
        }

        /// Run the user provided initializer. This *must* only be called once.
        ///
        /// - Returns: An `EventLoopFuture<LambdaHandler>` fulfilled with the outcome of the initialization.
        func initialize(logger: Logger, factory: @escaping LambdaHandlerFactory) -> EventLoopFuture<ByteBufferLambdaHandler> {
            logger.debug("initializing lambda")
            // 1. create the handler from the factory
            let future = bootstrap(eventLoop: self.eventLoop, lifecycleId: self.lifecycleId, offload: self.offload, factory: factory)
            // 2. report initialization error if one occured
            return future.peekError { error in
                self.runtimeClient.reportInitializationError(logger: logger, error: error).peekError { reportingError in
                    // We're going to bail out because the init failed, so there's not a lot we can do other than log
                    // that we couldn't report this error back to the runtime.
                    logger.error("failed reporting initialization error to lambda runtime engine: \(reportingError)")
                }
            }
        }

        func run(logger: Logger, handler: ByteBufferLambdaHandler) -> EventLoopFuture<Void> {
            logger.debug("lambda invocation sequence starting")
            // 1. request work from lambda runtime engine
            return self.runtimeClient.requestWork(logger: logger).peekError { error in
                logger.error("could not fetch work from lambda runtime engine: \(error)")
            }.flatMap { invocation, payload in
                // 2. send work to handler
                let context = Context(logger: logger, eventLoop: self.eventLoop, invocation: invocation)
                logger.debug("sending work to lambda handler \(handler)")
                return handler.handle(eventLoop: self.eventLoop,
                                      lifecycleId: self.lifecycleId,
                                      offload: self.offload,
                                      context: context,
                                      payload: payload).mapResult { (invocation, $0) }
            }.flatMap { invocation, result in
                // 3. report results to runtime engine
                self.runtimeClient.reportResults(logger: logger, invocation: invocation, result: result).peekError { error in
                    logger.error("could not report results to lambda runtime engine: \(error)")
                }
            }.always { result in
                // we are done!
                logger.log(level: result.successful ? .debug : .warning, "lambda invocation sequence completed \(result.successful ? "successfully" : "with failure")")
            }
        }
    }
}

// FIXME: offload
private func bootstrap(eventLoop: EventLoop, lifecycleId: String, offload: Bool, factory: @escaping LambdaHandlerFactory) -> EventLoopFuture<ByteBufferLambdaHandler> {
    let promise = eventLoop.makePromise(of: ByteBufferLambdaHandler.self)
    /* if offload {
         // offloading so user code never blocks the eventloop
         DispatchQueue(label: "lambda-\(lifecycleId)").async {
             factory(eventLoop, promise.completeWith)
         }
     } else {
         factory(eventLoop, promise.completeWith)
     } */
    factory(eventLoop, promise)
    return promise.futureResult
}

private extension ByteBufferLambdaHandler {
    // FIXME: offload
    func handle(eventLoop: EventLoop, lifecycleId: String, offload: Bool, context: Lambda.Context, payload: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
        let promise = eventLoop.makePromise(of: ByteBuffer?.self)
        self.handle(context: context, payload: payload, promise: promise)
        return promise.futureResult

        /* let promise = eventLoop.makePromise(of: LambdaResult.self)
         if offload {
             // offloading so user code never blocks the eventloop
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
    }
}

private extension Lambda.Context {
    convenience init(logger: Logger, eventLoop: EventLoop, invocation: Lambda.Invocation) {
        self.init(requestId: invocation.requestId,
                  traceId: invocation.traceId,
                  invokedFunctionArn: invocation.invokedFunctionArn,
                  deadline: DispatchWallTime(millisSinceEpoch: invocation.deadlineInMillisSinceEpoch),
                  cognitoIdentity: invocation.cognitoIdentity,
                  clientContext: invocation.clientContext,
                  logger: logger,
                  eventLoop: eventLoop)
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
        case .failure:
            return false
        }
    }
}
