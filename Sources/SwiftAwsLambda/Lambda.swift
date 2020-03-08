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
import Dispatch
import Logging
import NIO
import NIOConcurrencyHelpers

public enum Lambda {
    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ handler: LambdaHandler) {
        self.run(handler: handler)
    }

    /// Run a Lambda defined by implementing the `LambdaHandler` protocol.
    ///
    /// - note: This is a blocking operation that will run forever, as it's lifecycle is managed by the AWS Lambda Runtime Engine.
    @inlinable
    public static func run(_ provider: @escaping (EventLoop) throws -> LambdaHandler) {
        self.run(provider: provider)
    }

    // for testing and internal use
    @usableFromInline
    @discardableResult
    internal static func run(handler: LambdaHandler, configuration: Configuration = .init()) -> Result<Int, Error> {
        self.run(provider: { _ in handler }, configuration: configuration)
    }

    // for testing and internal use
    @usableFromInline
    @discardableResult
    internal static func run(provider: @escaping (EventLoop) throws -> LambdaHandler, configuration: Configuration = .init()) -> Result<Int, Error> {
        do {
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1) // only need one thread, will improve performance
            defer { try! eventLoopGroup.syncShutdownGracefully() }
            let result = try self.runAsync(eventLoopGroup: eventLoopGroup, provider: provider, configuration: configuration).wait()
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    internal static func runAsync(eventLoopGroup: EventLoopGroup, provider: @escaping (EventLoop) throws -> LambdaHandler, configuration: Configuration) -> EventLoopFuture<Int> {
        Backtrace.install()
        var logger = Logger(label: "Lambda")
        logger.logLevel = configuration.general.logLevel
        let lifecycle = Lifecycle(eventLoop: eventLoopGroup.next(), logger: logger, configuration: configuration, provider: provider)
        let signalSource = trap(signal: configuration.lifecycle.stopSignal) { signal in
            logger.info("intercepted signal: \(signal)")
            lifecycle.stop()
        }
        return lifecycle.start().always { _ in
            lifecycle.shutdown()
            signalSource.cancel()
        }
    }

    private final class Lifecycle {
        private let eventLoop: EventLoop
        private let logger: Logger
        private let configuration: Configuration
        private let provider: (EventLoop) throws -> LambdaHandler

        private var _state = LifecycleState.idle
        private let stateLock = Lock()

        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, provider: @escaping (EventLoop) throws -> LambdaHandler) {
            self.eventLoop = eventLoop
            self.logger = logger
            self.configuration = configuration
            self.provider = provider
        }

        deinit {
            precondition(self.state == .shutdown, "invalid state \(self.state)")
        }

        private var state: LifecycleState {
            get {
                return self.stateLock.withLock {
                    self._state
                }
            }
            set {
                self.stateLock.withLockVoid {
                    precondition(newValue.rawValue > _state.rawValue, "invalid state \(newValue) after \(_state)")
                    self._state = newValue
                }
            }
        }

        func start() -> EventLoopFuture<Int> {
            logger.info("lambda lifecycle starting with \(self.configuration)")
            self.state = .initializing
            var logger = self.logger
            logger[metadataKey: "lifecycleId"] = .string(self.configuration.lifecycle.id)
            let runner = Runner(eventLoop: self.eventLoop, configuration: self.configuration, provider: self.provider)
            return runner.initialize(logger: logger).flatMap { handler in
                self.state = .active
                return self.run(runner: runner, handler: handler)
            }
        }

        func stop() {
            self.logger.info("lambda lifecycle stopping")
            self.state = .stopping
        }

        func shutdown() {
            self.logger.info("lambda lifecycle shutdown")
            self.state = .shutdown
        }

        @inline(__always)
        private func run(runner: Runner, handler: LambdaHandler) -> EventLoopFuture<Int> {
            let promise = self.eventLoop.makePromise(of: Int.self)

            func _run(_ count: Int) {
                switch self.state {
                case .active:
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
    }

    @usableFromInline
    internal struct Configuration: CustomStringConvertible {
        let general: General
        let lifecycle: Lifecycle
        let runtimeEngine: RuntimeEngine

        @usableFromInline
        init() {
            self.init(general: .init(), lifecycle: .init(), runtimeEngine: .init())
        }

        init(general: General? = nil, lifecycle: Lifecycle? = nil, runtimeEngine: RuntimeEngine? = nil) {
            self.general = general ?? General()
            self.lifecycle = lifecycle ?? Lifecycle()
            self.runtimeEngine = runtimeEngine ?? RuntimeEngine()
        }

        struct General: CustomStringConvertible {
            let logLevel: Logger.Level

            init(logLevel: Logger.Level? = nil) {
                self.logLevel = logLevel ?? env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info
            }

            var description: String {
                return "\(General.self)(logLevel: \(self.logLevel))"
            }
        }

        struct Lifecycle: CustomStringConvertible {
            let id: String
            let maxTimes: Int
            let stopSignal: Signal

            init(id: String? = nil, maxTimes: Int? = nil, stopSignal: Signal? = nil) {
                self.id = id ?? "\(DispatchTime.now().uptimeNanoseconds)"
                self.maxTimes = maxTimes ?? env("MAX_REQUESTS").flatMap(Int.init) ?? 0
                self.stopSignal = stopSignal ?? env("STOP_SIGNAL").flatMap(Int32.init).flatMap(Signal.init) ?? Signal.TERM
                precondition(self.maxTimes >= 0, "maxTimes must be equal or larger than 0")
            }

            var description: String {
                return "\(Lifecycle.self)(id: \(self.id), maxTimes: \(self.maxTimes), stopSignal: \(self.stopSignal))"
            }
        }

        struct RuntimeEngine: CustomStringConvertible {
            let ip: String
            let port: Int
            let keepAlive: Bool
            let requestTimeout: TimeAmount?
            let offload: Bool

            init(baseURL: String? = nil, keepAlive: Bool? = nil, requestTimeout: TimeAmount? = nil, offload: Bool? = nil) {
                let ipPort = env("AWS_LAMBDA_RUNTIME_API")?.split(separator: ":") ?? ["127.0.0.1", "7000"]
                guard ipPort.count == 2, let port = Int(ipPort[1]) else {
                    preconditionFailure("invalid ip+port configuration \(ipPort)")
                }
                self.ip = String(ipPort[0])
                self.port = port
                self.keepAlive = keepAlive ?? env("KEEP_ALIVE").flatMap(Bool.init) ?? true
                self.requestTimeout = requestTimeout ?? env("REQUEST_TIMEOUT").flatMap(Int64.init).flatMap { .milliseconds($0) }
                self.offload = offload ?? env("OFFLOAD").flatMap(Bool.init) ?? false
            }

            var description: String {
                return "\(RuntimeEngine.self)(ip: \(self.ip), port: \(self.port), keepAlive: \(self.keepAlive), requestTimeout: \(String(describing: self.requestTimeout)), offload: \(self.offload)"
            }
        }

        @usableFromInline
        var description: String {
            return "\(Configuration.self)\n  \(self.general))\n  \(self.lifecycle)\n  \(self.runtimeEngine)"
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

/// A processing protocol for a Lambda that takes a `ByteBuffer` and returns an optional `ByteBuffer`  asynchronously via an `EventLoopPromise`.
public protocol LambdaHandler {
    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>)
}

public protocol BootstrappedLambdaHandler: LambdaHandler {
    /// Bootstraps the `LambdaHandler`.
    func bootstrap(eventLoop: EventLoop, promise: EventLoopPromise<Void>)
}

extension Lambda {
    public struct Context {
        // from aws
        public let requestId: String
        public let traceId: String?
        public let invokedFunctionArn: String?
        public let cognitoIdentity: String?
        public let clientContext: String?
        public let deadline: String?
        // utliity
        public let eventLoop: EventLoop
        public let allocator: ByteBufferAllocator
        public let logger: Logger

        public init(requestId: String,
                    traceId: String? = nil,
                    invokedFunctionArn: String? = nil,
                    cognitoIdentity: String? = nil,
                    clientContext: String? = nil,
                    deadline: String? = nil,
                    eventLoop: EventLoop,
                    logger: Logger) {
            self.requestId = requestId
            self.traceId = traceId
            self.invokedFunctionArn = invokedFunctionArn
            self.cognitoIdentity = cognitoIdentity
            self.clientContext = clientContext
            self.deadline = deadline
            // utility
            self.eventLoop = eventLoop
            self.allocator = ByteBufferAllocator()
            // mutate logger with context
            var logger = logger
            logger[metadataKey: "awsRequestId"] = .string(requestId)
            if let traceId = traceId {
                logger[metadataKey: "awsTraceId"] = .string(traceId)
            }
            self.logger = logger
        }
    }
}
