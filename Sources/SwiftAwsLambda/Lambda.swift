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

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Backtrace
import Foundation
import Logging
import NIO
import NIOConcurrencyHelpers

public enum Lambda {
    /// Run a Lambda defined by implementing the `LambdaClosure` closure.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ closure: @escaping LambdaClosure) {
        let _: LambdaLifecycleResult = self.run(closure)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ handler: LambdaHandler) {
        let _: LambdaLifecycleResult = self.run(handler: handler)
    }

    // for testing
    internal static func run(maxTimes: Int = 0, stopSignal: Signal = .TERM, _ closure: @escaping LambdaClosure) -> LambdaLifecycleResult {
        return self.run(handler: LambdaClosureWrapper(closure), maxTimes: maxTimes, stopSignal: stopSignal)
    }

    // for testing
    internal static func run(handler: LambdaHandler, maxTimes: Int = 0, stopSignal: Signal = .TERM) -> LambdaLifecycleResult {
        do {
            return try self.runAsync(handler: handler, maxTimes: maxTimes, stopSignal: stopSignal).wait()
        } catch {
            return .failure(error)
        }
    }

    internal static func runAsync(handler: LambdaHandler, maxTimes: Int = 0, stopSignal: Signal = .TERM) -> EventLoopFuture<LambdaLifecycleResult> {
        let logger = Logger(label: "Lambda")
        let lifecycle = Lifecycle(logger: logger, handler: handler, maxTimes: maxTimes)
        Backtrace.install()
        let signalSource = trap(signal: stopSignal) { signal in
            logger.info("intercepted signal: \(signal)")
            lifecycle.stop()
        }
        let future = lifecycle.start()
        future.whenComplete { _ in
            lifecycle.stop()
            signalSource.cancel()
        }
        return future
    }

    private class Lifecycle {
        private let logger: Logger
        private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        private let handler: LambdaHandler
        private let max: Int

        private var _state = LifecycleState.idle
        private let stateLock = Lock()

        init(logger: Logger, handler: LambdaHandler, maxTimes: Int) {
            assert(maxTimes >= 0, "maxTimes must be larger than 0")
            self.logger = logger
            self.handler = handler
            self.max = maxTimes
            self.logger.info("lambda lifecycle init")
        }

        deinit {
            self.logger.info("lambda lifecycle deinit")
            assert(state == .shutdown)
        }

        private var state: LifecycleState {
            get {
                return self.stateLock.withLock {
                    self._state
                }
            }
            set {
                self.stateLock.withLockVoid {
                    assert(newValue.rawValue > _state.rawValue, "invalid state \(newValue) after \(_state)")
                    self._state = newValue
                }
            }
        }

        func start() -> EventLoopFuture<LambdaLifecycleResult> {
            self.state = .initializing
            var logger = self.logger
            logger[metadataKey: "lifecycleId"] = .string(NSUUID().uuidString)
            let runner = LambdaRunner(eventLoopGroup: eventLoopGroup, lambdaHandler: handler)
            let promise = self.eventLoopGroup.next().makePromise(of: LambdaLifecycleResult.self)
            self.logger.info("lambda lifecycle starting")

            runner.initialize(logger: logger).whenComplete { result in
                switch result {
                case .failure(let error):
                    promise.succeed(.failure(error))
                case .success:
                    DispatchQueue.global().async {
                        var lastError: Error?
                        var counter = 0
                        self.state = .active // initializtion completed successfully, we're good to go!
                        while self.state == .active, lastError == nil, self.max == 0 || counter < self.max {
                            do {
                                logger[metadataKey: "lifecycleIteration"] = "\(counter)"
                                // blocking! per aws lambda runtime spec the polling requests are to be done one at a time
                                switch try runner.run(logger: logger).wait() {
                                case .success:
                                    counter = counter + 1
                                case .failure(let error):
                                    if self.state == .active {
                                        lastError = error
                                    }
                                }
                            } catch {
                                if self.state == .active {
                                    lastError = error
                                }
                            }
                            // flush the log streams so entries are printed with a single invocation
                            // TODO: should we suuport a flush API in swift-log's default logger?
                            fflush(stdout)
                            fflush(stderr)
                        }
                        promise.succeed(lastError.map { .failure($0) } ?? .success(counter))
                    }
                }
            }
            return promise.futureResult
        }

        func stop() {
            if self.state == .stopping {
                return self.logger.info("lambda lifecycle aready stopping")
            }
            if self.state == .shutdown {
                return self.logger.info("lambda lifecycle aready shutdown")
            }
            self.logger.info("lambda lifecycle stopping")
            self.state = .stopping
            try! self.eventLoopGroup.syncShutdownGracefully()
            self.state = .shutdown
        }
    }

    private enum LifecycleState: Int {
        case idle
        case initializing
        case active
        case stopping
        case shutdown
    }
}

/// A result type for a Lambda that returns a `[UInt8]`.
public typealias LambdaResult = Result<[UInt8], Error>

public typealias LambdaCallback = (LambdaResult) -> Void

/// A processing closure for a Lambda that takes a `[UInt8]` and returns a `LambdaResult` result type asynchronously.
public typealias LambdaClosure = (LambdaContext, [UInt8], LambdaCallback) -> Void

/// A result type for a Lambda initialization.
public typealias LambdaInitResult = Result<Void, Error>

/// A callback to provide the result of Lambda initialization.
public typealias LambdaInitCallBack = (LambdaInitResult) -> Void

/// A processing protocol for a Lambda that takes a `[UInt8]` and returns a `LambdaResult` result type asynchronously.
public protocol LambdaHandler {
    /// Initializes the `LambdaHandler`.
    func initialize(callback: @escaping LambdaInitCallBack)
    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback)
}

extension LambdaHandler {
    public func initialize(callback: @escaping LambdaInitCallBack) {
        callback(.success(()))
    }
}

public struct LambdaContext {
    // from aws
    public let requestId: String
    public let traceId: String?
    public let invokedFunctionArn: String?
    public let cognitoIdentity: String?
    public let clientContext: String?
    public let deadline: String?
    // utliity
    public let logger: Logger

    public init(requestId: String,
                traceId: String? = nil,
                invokedFunctionArn: String? = nil,
                cognitoIdentity: String? = nil,
                clientContext: String? = nil,
                deadline: String? = nil,
                logger: Logger) {
        self.requestId = requestId
        self.traceId = traceId
        self.invokedFunctionArn = invokedFunctionArn
        self.cognitoIdentity = cognitoIdentity
        self.clientContext = clientContext
        self.deadline = deadline
        self.logger = logger
    }
}

internal typealias LambdaLifecycleResult = Result<Int, Error>

private struct LambdaClosureWrapper: LambdaHandler {
    private let closure: LambdaClosure
    init(_ closure: @escaping LambdaClosure) {
        self.closure = closure
    }

    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        self.closure(context, payload, callback)
    }
}
