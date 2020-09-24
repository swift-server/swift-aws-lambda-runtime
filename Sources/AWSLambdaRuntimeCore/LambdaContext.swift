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

import BaggageContext
import Dispatch
import Logging
import NIO

// MARK: - InitializationContext

extension Lambda {
    /// Lambda runtime initialization context.
    /// The Lambda runtime generates and passes the `InitializationContext` to the Lambda factory as an argument.
    public final class InitializationContext {
        /// `Logger` to log with
        ///
        /// - note: The `LogLevel` can be configured using the `LOG_LEVEL` environment variable.
        public let logger: Logger

        /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
        ///
        /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
        ///         Most importantly the `EventLoop` must never be blocked.
        public let eventLoop: EventLoop

        /// `ByteBufferAllocator` to allocate `ByteBuffer`
        public let allocator: ByteBufferAllocator

        internal init(logger: Logger, eventLoop: EventLoop, allocator: ByteBufferAllocator) {
            self.eventLoop = eventLoop
            self.logger = logger
            self.allocator = allocator
        }
    }
}

// MARK: - Context

extension Lambda {
    /// Lambda runtime context.
    /// The Lambda runtime generates and passes the `Context` to the Lambda handler as an argument.
    public struct Context: BaggageContext.Context, CustomDebugStringConvertible {
        /// Used to store all contents of the context and implement CoW semantics for it.
        private var storage: Storage

        final class Storage {
            var baggage: Baggage

            let invokedFunctionARN: String
            let deadline: DispatchWallTime
            let cognitoIdentity: String?
            let clientContext: String?

            // Implementation note: This logger is the "user provided logger" that we will log to when `context.logger` is used.
            // It must be updated with the latest metadata whenever the `baggage` changes.
            var _logger: Logger

            let eventLoop: EventLoop
            let allocator: ByteBufferAllocator

            init(
                baggage: Baggage,
                invokedFunctionARN: String,
                deadline: DispatchWallTime,
                cognitoIdentity: String?,
                clientContext: String?,
                logger: Logger,
                eventLoop: EventLoop,
                allocator: ByteBufferAllocator
            ) {
                self.baggage = baggage
                self.invokedFunctionARN = invokedFunctionARN
                self.deadline = deadline
                self.cognitoIdentity = cognitoIdentity
                self.clientContext = clientContext
                self._logger = logger
                self.eventLoop = eventLoop
                self.allocator = allocator
            }
        }

        /// Contains contextual metadata such as request and trace identifiers, along with other information which may
        /// be carried throughout asynchronous and cross-node boundaries (e.g. through HTTPClient calls).
        public var baggage: Baggage {
            get {
                self.storage.baggage
            }
            set {
                if isKnownUniquelyReferenced(&self.storage) {
                    self.storage._logger.updateMetadata(previous: self.storage.baggage, latest: newValue)
                    self.storage.baggage = newValue
                } else {
                    var logger = self.storage._logger
                    logger.updateMetadata(previous: self.storage.baggage, latest: newValue)
                    self.storage = Storage(
                        baggage: newValue,
                        invokedFunctionARN: self.storage.invokedFunctionARN,
                        deadline: self.storage.deadline,
                        cognitoIdentity: self.storage.cognitoIdentity,
                        clientContext: self.storage.clientContext,
                        logger: self.storage._logger,
                        eventLoop: self.storage.eventLoop,
                        allocator: self.storage.allocator
                    )
                }
            }
        }

        /// The request ID, which identifies the request that triggered the function invocation.
        public var requestID: String {
            self.storage.baggage.lambdaRequestID
        }

        /// The AWS X-Ray tracing header.
        public var traceID: String {
            self.storage.baggage.lambdaTraceID
        }

        /// The ARN of the Lambda function, version, or alias that's specified in the invocation.
        public var invokedFunctionARN: String {
            self.storage.invokedFunctionARN
        }

        /// The timestamp that the function times out
        public var deadline: DispatchWallTime {
            self.storage.deadline
        }

        /// For invocations from the AWS Mobile SDK, data about the Amazon Cognito identity provider.
        public var cognitoIdentity: String? {
            self.storage.cognitoIdentity
        }

        /// For invocations from the AWS Mobile SDK, data about the client application and device.
        public var clientContext: String? {
            self.storage.clientContext
        }

        /// `Logger` to log with, it is automatically populated with `baggage` information (such as `traceID` and `requestID`).
        ///
        /// - note: The default `Logger.LogLevel` can be configured using the `LOG_LEVEL` environment variable.
        public var logger: Logger {
            get {
                self.storage._logger
            }
            set {
                if isKnownUniquelyReferenced(&self.storage) {
                    self.storage._logger = newValue
                    self.storage._logger.updateMetadata(previous: .topLevel, latest: self.storage.baggage)
                }
            }
        }

        /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
        /// This is useful when implementing the `EventLoopLambdaHandler` protocol.
        ///
        /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
        ///         Most importantly the `EventLoop` must never be blocked.
        public var eventLoop: EventLoop {
            self.storage.eventLoop
        }

        /// `ByteBufferAllocator` to allocate `ByteBuffer`
        /// This is useful when implementing `EventLoopLambdaHandler`
        public var allocator: ByteBufferAllocator {
            self.storage.allocator
        }

        internal init(requestID: String,
                      traceID: String,
                      invokedFunctionARN: String,
                      deadline: DispatchWallTime,
                      cognitoIdentity: String? = nil,
                      clientContext: String? = nil,
                      logger: Logger,
                      eventLoop: EventLoop,
                      allocator: ByteBufferAllocator) {
            var baggage = Baggage.topLevel
            baggage.lambdaRequestID = requestID
            baggage.lambdaTraceID = traceID
            self.storage = Storage(
                baggage: baggage,
                invokedFunctionARN: invokedFunctionARN,
                deadline: deadline,
                cognitoIdentity: cognitoIdentity,
                clientContext: clientContext,
                // utility
                logger: logger,
                eventLoop: eventLoop,
                allocator: allocator
            )
        }

        public func getRemainingTime() -> TimeAmount {
            let deadline = self.deadline.millisSinceEpoch
            let now = DispatchWallTime.now().millisSinceEpoch

            let remaining = deadline - now
            return .milliseconds(remaining)
        }

        public var debugDescription: String {
            "\(Self.self)(requestID: \(self.requestID), traceID: \(self.traceID), invokedFunctionARN: \(self.invokedFunctionARN), cognitoIdentity: \(self.cognitoIdentity ?? "nil"), clientContext: \(self.clientContext ?? "nil"), deadline: \(self.deadline))"
        }
    }
}

// MARK: - ShutdownContext

extension Lambda {
    /// Lambda runtime shutdown context.
    /// The Lambda runtime generates and passes the `ShutdownContext` to the Lambda handler as an argument.
    public final class ShutdownContext {
        /// `Logger` to log with
        ///
        /// - note: The `LogLevel` can be configured using the `LOG_LEVEL` environment variable.
        public let logger: Logger

        /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
        ///
        /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
        ///         Most importantly the `EventLoop` must never be blocked.
        public let eventLoop: EventLoop

        internal init(logger: Logger, eventLoop: EventLoop) {
            self.eventLoop = eventLoop
            self.logger = logger
        }
    }
}

// MARK: - Baggage Items

extension Baggage {

    // MARK: - Baggage: RequestID

    enum LambdaRequestIDKey: Key {
        typealias Value = String
        static var name: String? { AmazonHeaders.requestID }
    }

    /// The request ID, which identifies the request that triggered the function invocation.
    public internal(set) var lambdaRequestID: String {
        get {
            self[LambdaRequestIDKey.self]! // !-safe, the runtime guarantees to always set an identifier, even in testing
        }
        set {
            self[LambdaRequestIDKey.self] = newValue
        }
    }

    // MARK: - Baggage: TraceID

    enum LambdaTraceIDKey: Key {
        typealias Value = String
        static var name: String? { AmazonHeaders.traceID }
    }

    /// The AWS X-Ray tracing header.
    public internal(set) var lambdaTraceID: String {
        get {
            self[LambdaTraceIDKey.self]! // !-safe, the runtime guarantees to always set an identifier, even in testing
        }
        set {
            self[LambdaTraceIDKey.self] = newValue
        }
    }
}
