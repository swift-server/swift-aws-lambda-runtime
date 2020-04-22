//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import NIOConcurrencyHelpers

extension Lambda {
    public final class Lifecycle {
        private let eventLoop: EventLoop
        private let shutdownPromise: EventLoopPromise<Int>
        private let logger: Logger
        private let configuration: Configuration
        private let factory: LambdaHandlerFactory

        private var _state = State.idle
        private let stateLock = Lock()

        public convenience init(eventLoop: EventLoop, logger: Logger, factory: @escaping LambdaHandlerFactory) {
            self.init(eventLoop: eventLoop, logger: logger, configuration: .init(), factory: factory)
        }

        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, factory: @escaping LambdaHandlerFactory) {
            self.eventLoop = eventLoop
            self.shutdownPromise = eventLoop.makePromise(of: Int.self)
            self.logger = logger
            self.configuration = configuration
            self.factory = factory
        }

        deinit {
            guard case .shutdown = self.state else {
                preconditionFailure("invalid state \(self.state)")
            }
        }

        private var state: State {
            get {
                self.stateLock.withLock {
                    self._state
                }
            }
            set {
                self.stateLock.withLockVoid {
                    precondition(newValue.order > self._state.order, "invalid state \(newValue) after \(self._state)")
                    self._state = newValue
                }
                self.logger.debug("lambda lifecycle state: \(newValue)")
            }
        }

        public var shutdownFuture: EventLoopFuture<Int> {
            self.shutdownPromise.futureResult
        }

        public func start() -> EventLoopFuture<Void> {
            logger.info("lambda lifecycle starting with \(self.configuration)")
            self.state = .initializing
            let promise = self.eventLoop.makePromise(of: Int.self)
            promise.futureResult.always { _ in
                self.markShutdown()
            }.cascade(to: self.shutdownPromise)
            var logger = self.logger
            logger[metadataKey: "lifecycleId"] = .string(self.configuration.lifecycle.id)
            let runner = Runner(eventLoop: self.eventLoop, configuration: self.configuration)
            return runner.initialize(logger: logger, factory: self.factory).map { handler in
                self.state = .active(runner, handler)
                self.run(promise: promise)
            }
        }

        public func shutdown() {
            self.state = .shuttingdown
        }

        private func markShutdown() {
            self.state = .shutdown
        }

        @inline(__always)
        private func run(promise: EventLoopPromise<Int>) {
            func _run(_ count: Int) {
                switch self.state {
                case .active(let runner, let handler):
                    if self.configuration.lifecycle.maxTimes > 0, count >= self.configuration.lifecycle.maxTimes {
                        return promise.succeed(count)
                    }
                    var logger = self.logger
                    logger[metadataKey: "lifecycleIteration"] = "\(count)"
                    runner.run(logger: logger, handler: handler).whenComplete { result in
                        switch result {
                        case .success:
                            // recursive! per aws lambda runtime spec the polling requests are to be done one at a time
                            _run(count + 1)
                        case .failure(let error):
                            promise.fail(error)
                        }
                    }
                case .shuttingdown:
                    promise.succeed(count)
                default:
                    preconditionFailure("invalid run state: \(self.state)")
                }
            }

            _run(0)
        }

        private enum State {
            case idle
            case initializing
            case active(Runner, ByteBufferLambdaHandler)
            case shuttingdown
            case shutdown

            internal var order: Int {
                switch self {
                case .idle:
                    return 0
                case .initializing:
                    return 1
                case .active:
                    return 2
                case .shuttingdown:
                    return 3
                case .shutdown:
                    return 4
                }
            }
        }
    }
}
