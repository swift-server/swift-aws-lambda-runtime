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
import NIO

extension Lambda {
    /// LambdaRunner manages the Lambda runtime workflow, or business logic.
    internal final class Runner {
        private let runtimeClient: RuntimeClient
        private let eventLoop: EventLoop
        private let allocator: ByteBufferAllocator

        private var isGettingNextInvocation = false

        init(eventLoop: EventLoop, configuration: Configuration) {
            self.eventLoop = eventLoop
            self.runtimeClient = RuntimeClient(eventLoop: self.eventLoop, configuration: configuration.runtimeEngine)
            self.allocator = ByteBufferAllocator()
        }

        /// Run the user provided initializer. This *must* only be called once.
        ///
        /// - Returns: An `EventLoopFuture<LambdaHandler>` fulfilled with the outcome of the initialization.
        func initialize(logger: Logger, factory: @escaping HandlerFactory) -> EventLoopFuture<Handler> {
            logger.debug("initializing lambda")
            // 1. create the handler from the factory
            // 2. report initialization error if one occured
            let context = InitializationContext(logger: logger,
                                                eventLoop: self.eventLoop,
                                                allocator: self.allocator)
            return factory(context)
                // Hopping back to "our" EventLoop is importnant in case the factory returns a future
                // that originated from a foreign EventLoop/EventLoopGroup.
                // This can happen if the factory uses a library (let's say a database client) that manages its own threads/loops
                // for whatever reason and returns a future that originated from that foreign EventLoop.
                .hop(to: self.eventLoop)
                .peekError { error in
                    self.runtimeClient.reportInitializationError(logger: logger, error: error).peekError { reportingError in
                        // We're going to bail out because the init failed, so there's not a lot we can do other than log
                        // that we couldn't report this error back to the runtime.
                        logger.error("failed reporting initialization error to lambda runtime engine: \(reportingError)")
                    }
                }
        }

        func run(logger: Logger, handler: Handler) -> EventLoopFuture<Void> {
            logger.debug("lambda invocation sequence starting")
            // 1. request invocation from lambda runtime engine
            self.isGettingNextInvocation = true
            return self.runtimeClient.getNextInvocation(logger: logger).peekError { error in
                logger.error("could not fetch work from lambda runtime engine: \(error)")
            }.flatMap { invocation, event in
                // 2. send invocation to handler
                self.isGettingNextInvocation = false
                let context = Context(logger: logger,
                                      eventLoop: self.eventLoop,
                                      allocator: self.allocator,
                                      invocation: invocation)
                logger.debug("sending invocation to lambda handler \(handler)")
                return handler.handle(context: context, event: event)
                    // Hopping back to "our" EventLoop is importnant in case the handler returns a future that
                    // originiated from a foreign EventLoop/EventLoopGroup.
                    // This can happen if the handler uses a library (lets say a DB client) that manages its own threads/loops
                    // for whatever reason and returns a future that originated from that foreign EventLoop.
                    .hop(to: self.eventLoop)
                    .mapResult { result in
                        if case .failure(let error) = result {
                            logger.warning("lambda handler returned an error: \(error)")
                        }
                        return (invocation, result)
                    }
            }.flatMap { invocation, result in
                // 3. report results to runtime engine
                self.runtimeClient.reportResults(logger: logger, invocation: invocation, result: result).peekError { error in
                    logger.error("could not report results to lambda runtime engine: \(error)")
                }
            }
        }

        /// cancels the current run, if we are waiting for next invocation (long poll from Lambda control plane)
        /// only needed for debugging purposes.
        func cancelWaitingForNextInvocation() {
            if self.isGettingNextInvocation {
                self.runtimeClient.cancel()
            }
        }
    }
}

private extension Lambda.Context {
    convenience init(logger: Logger, eventLoop: EventLoop, allocator: ByteBufferAllocator, invocation: Lambda.Invocation) {
        self.init(requestID: invocation.requestID,
                  traceID: invocation.traceID,
                  invokedFunctionARN: invocation.invokedFunctionARN,
                  deadline: DispatchWallTime(millisSinceEpoch: invocation.deadlineInMillisSinceEpoch),
                  cognitoIdentity: invocation.cognitoIdentity,
                  clientContext: invocation.clientContext,
                  logger: logger,
                  eventLoop: eventLoop,
                  allocator: allocator)
    }
}

// TODO: move to nio?
extension EventLoopFuture {
    // callback does not have side effects, failing with original result
    func peekError(_ callback: @escaping (Error) -> Void) -> EventLoopFuture<Value> {
        self.flatMapError { error in
            callback(error)
            return self
        }
    }

    // callback does not have side effects, failing with original result
    func peekError(_ callback: @escaping (Error) -> EventLoopFuture<Void>) -> EventLoopFuture<Value> {
        self.flatMapError { error in
            let promise = self.eventLoop.makePromise(of: Value.self)
            callback(error).whenComplete { _ in
                promise.completeWith(self)
            }
            return promise.futureResult
        }
    }

    func mapResult<NewValue>(_ callback: @escaping (Result<Value, Error>) -> NewValue) -> EventLoopFuture<NewValue> {
        self.map { value in
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
