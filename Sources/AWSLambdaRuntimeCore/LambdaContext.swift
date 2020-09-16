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

import Dispatch
import Logging
import NIO
import BaggageContext

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
    public final class Context: BaggageContext.Context, CustomDebugStringConvertible {

        /// Contains contextual metadata such as request and trace identifiers, along with other information which may
        /// be carried throughout asynchronous and cross-node boundaries (e.g. through HTTPClient calls).
        public let baggage: Baggage

        /// The request ID, which identifies the request that triggered the function invocation.
        public var requestID: String {
            self.baggage.lambdaRequestID
        }

        /// The AWS X-Ray tracing header.
        public var traceID: String {
            self.baggage.lambdaTraceID
        }

        /// The ARN of the Lambda function, version, or alias that's specified in the invocation.
        public let invokedFunctionARN: String

        /// The timestamp that the function times out
        public let deadline: DispatchWallTime

        /// For invocations from the AWS Mobile SDK, data about the Amazon Cognito identity provider.
        public let cognitoIdentity: String?

        /// For invocations from the AWS Mobile SDK, data about the client application and device.
        public let clientContext: String?

        /// `Logger` to log with, it is automatically populated with `baggage` information (such as `traceID` and `requestID`).
        ///
        /// - note: The `LogLevel` can be configured using the `LOG_LEVEL` environment variable.
        public var logger: Logger {
            self._logger.with(self.baggage)
        }
        private var _logger: Logger

        /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
        /// This is useful when implementing the `EventLoopLambdaHandler` protocol.
        ///
        /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
        ///         Most importantly the `EventLoop` must never be blocked.
        public let eventLoop: EventLoop

        /// `ByteBufferAllocator` to allocate `ByteBuffer`
        /// This is useful when implementing `EventLoopLambdaHandler`
        public let allocator: ByteBufferAllocator

        internal init(requestID: String,
                      traceID: String,
                      invokedFunctionARN: String,
                      deadline: DispatchWallTime,
                      cognitoIdentity: String? = nil,
                      clientContext: String? = nil,
                      logger: Logger,
                      eventLoop: EventLoop,
                      allocator: ByteBufferAllocator) {
            var baggage = Baggage.background
            baggage.lambdaRequestID = requestID
            baggage.lambdaTraceID = traceID
            self.baggage = baggage
            self.invokedFunctionARN = invokedFunctionARN
            self.cognitoIdentity = cognitoIdentity
            self.clientContext = clientContext
            self.deadline = deadline
            // utility
            self.eventLoop = eventLoop
            self.allocator = allocator
            self._logger = logger
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
            return self[LambdaRequestIDKey.self]! // !-safe, the runtime guarantees to always set an identifier, even in testing
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
            return self[LambdaTraceIDKey.self]! // !-safe, the runtime guarantees to always set an identifier, even in testing
        }
        set {
            self[LambdaTraceIDKey.self] = newValue
        }
    }

}
