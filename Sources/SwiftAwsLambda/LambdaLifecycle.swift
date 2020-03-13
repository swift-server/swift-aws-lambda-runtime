//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import NIOConcurrencyHelpers

extension Lambda {
    @usableFromInline
    internal final class Lifecycle {
        private let eventLoop: EventLoop
        private let logger: Logger
        private let configuration: Configuration
        private let factory: LambdaHandlerFactory

        private var _state = State.idle
        private let stateLock = Lock()

        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, factory: @escaping LambdaHandlerFactory) {
            self.eventLoop = eventLoop
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
                return self.stateLock.withLock {
                    self._state
                }
            }
            set {
                self.stateLock.withLockVoid {
                    precondition(newValue.order > _state.order, "invalid state \(newValue) after \(self._state)")
                    self._state = newValue
                }
            }
        }

        func start() -> EventLoopFuture<Int> {
            logger.info("lambda lifecycle starting with \(self.configuration)")
            self.state = .initializing
            var logger = self.logger
            logger[metadataKey: "lifecycleId"] = .string(self.configuration.lifecycle.id)
            let runner = Runner(eventLoop: self.eventLoop, configuration: self.configuration)
            return runner.initialize(logger: logger, factory: self.factory).flatMap { handler in
                self.state = .active(runner, handler)
                return self.run()
            }
        }

        func stop() {
            self.logger.debug("lambda lifecycle stopping")
            self.state = .stopping
        }

        func shutdown() {
            self.logger.debug("lambda lifecycle shutdown")
            self.state = .shutdown
        }

        @inline(__always)
        private func run() -> EventLoopFuture<Int> {
            let promise = self.eventLoop.makePromise(of: Int.self)

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
                case .stopping, .shutdown:
                    promise.succeed(count)
                default:
                    preconditionFailure("invalid run state: \(self.state)")
                }
            }

            _run(0)

            return promise.futureResult
        }

        private enum State {
            case idle
            case initializing
            case active(Runner, ByteBufferLambdaHandler)
            case stopping
            case shutdown

            internal var order: Int {
                switch self {
                case .idle:
                    return 0
                case .initializing:
                    return 1
                case .active:
                    return 2
                case .stopping:
                    return 3
                case .shutdown:
                    return 4
                }
            }
        }
    }
}
