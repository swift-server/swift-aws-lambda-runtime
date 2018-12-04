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
import NIO

public enum Lambda {
    /// Run a Lambda defined by implementing the `LambdaClosure` closure.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ closure: @escaping LambdaClosure) {
        let _: LambdaLifecycleResult = run(closure)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    public static func run(_ handler: LambdaHandler) {
        let _: LambdaLifecycleResult = run(handler: handler)
    }

    // for testing
    internal static func run(maxTimes: Int = 0, stopSignal: Signal = .INT, _ closure: @escaping LambdaClosure) -> LambdaLifecycleResult {
        return self.run(handler: LambdaClosureWrapper(closure), maxTimes: maxTimes, stopSignal: stopSignal)
    }

    // for testing
    internal static func run(handler: LambdaHandler, maxTimes: Int = 0, stopSignal: Signal = .INT) -> LambdaLifecycleResult {
        do {
            return try self.runAsync(handler: handler, maxTimes: maxTimes, stopSignal: stopSignal).wait()
        } catch {
            return .failure(error)
        }
    }

    internal static func runAsync(handler: LambdaHandler, maxTimes: Int = 0, stopSignal: Signal = .INT) -> EventLoopFuture<LambdaLifecycleResult> {
        let lifecycle = Lifecycle(handler: handler, maxTimes: maxTimes)
        let signalSource = trap(signal: stopSignal) { signal in
            print("intercepted signal: \(signal)")
            lifecycle.stop()
        }
        let future = lifecycle.start()
        future.whenComplete {
            signalSource.cancel()
        }
        return future
    }

    private class Lifecycle {
        private let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
        private let handler: LambdaHandler
        private let max: Int

        private var _state = LifecycleState.initialized
        private let stateQueue = DispatchQueue(label: "LifecycleState")

        init(handler: LambdaHandler, maxTimes: Int) {
            print("lambda lifecycle init")
            self.handler = handler
            self.max = maxTimes
            assert(self.max >= 0)
        }

        deinit {
            print("lambda lifecycle deinit")
            assert(state == .shutdown)
        }

        private var state: LifecycleState {
            get {
                return self.stateQueue.sync {
                    self._state
                }
            }
            set {
                self.stateQueue.sync {
                    assert(newValue.rawValue > _state.rawValue, "invalid state \(newValue) after \(_state)")
                    self._state = newValue
                }
            }
        }

        func start() -> EventLoopFuture<LambdaLifecycleResult> {
            self.state = .active
            let runner = LambdaRunner(eventLoop: eventLoop, lambdaHandler: handler)
            let promise: EventLoopPromise<LambdaLifecycleResult> = eventLoop.newPromise()
            print("lambda lifecycle statring")
            DispatchQueue.global().async {
                var err: Error?
                var counter = 0
                while .active == self.state && nil == err && (0 == self.max || counter < self.max) {
                    do {
                        // blocking! per aws lambda runtime spec the polling requets are to be done one at a time
                        let result = try runner.run().wait()
                        switch result {
                        case .success:
                            counter = counter + 1
                        case let .failure(e):
                            err = e
                        }
                    } catch {
                        err = error
                    }
                }
                promise.succeed(result: err.map { _ in .failure(err!) } ?? .success(counter))
                self.shutdown()
            }
            return promise.futureResult
        }

        func stop() {
            print("lambda lifecycle stopping")
            self.state = .stopping
        }

        private func shutdown() {
            try! self.eventLoop.syncShutdownGracefully()
            self.state = .shutdown
        }
    }

    private enum LifecycleState: Int {
        case initialized = 0
        case active = 1
        case stopping = 2
        case shutdown = 3
    }
}

/// A result type for a Lambda that returns a `[UInt8]`.
public typealias LambdaResult = ResultType<[UInt8], String>

public typealias LambdaCallback = (LambdaResult) -> Void

/// A processing closure for a Lambda that takes a `[UInt8]` and returns a `LambdaResult` result type asynchronously.
public typealias LambdaClosure = (LambdaContext, [UInt8], LambdaCallback) -> Void

/// A processing protocol for a Lambda that takes a `[UInt8]` and returns a `LambdaResult` result type asynchronously.
public protocol LambdaHandler {
    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback)
}

public struct LambdaContext {
    public let requestId: String
    public let traceId: String?
    public let invokedFunctionArn: String?
    public let cognitoIdentity: String?
    public let clientContext: String?
    public let deadline: String?

    public init(requestId: String, traceId: String? = nil, invokedFunctionArn: String? = nil, cognitoIdentity: String? = nil, clientContext: String? = nil, deadline: String? = nil) {
        self.requestId = requestId
        self.traceId = traceId
        self.invokedFunctionArn = invokedFunctionArn
        self.cognitoIdentity = cognitoIdentity
        self.clientContext = clientContext
        self.deadline = deadline
    }
}

internal typealias LambdaLifecycleResult = ResultType<Int, Error>

private struct LambdaClosureWrapper: LambdaHandler {
    private let closure: LambdaClosure
    init(_ closure: @escaping LambdaClosure) {
        self.closure = closure
    }

    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        self.closure(context, payload, callback)
    }
}
