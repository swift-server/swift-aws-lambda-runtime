//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if LocalServerSupport
import DequeModule
import Synchronization

@available(LambdaSwift 2.0, *)
extension LambdaHTTPServer {
    /// A shared data structure to store the current invocation or response requests and the continuation objects.
    /// This data structure is shared between instances of the HTTPHandler
    /// (one instance to serve requests from the Lambda function and one instance to serve requests from the client invoking the lambda function).
    internal final class Pool<T>: AsyncSequence, AsyncIteratorProtocol, Sendable where T: Sendable {
        private let poolName: String
        internal init(name: String = "Pool") { self.poolName = name }

        typealias Element = T

        enum State: ~Copyable {
            case buffer(Deque<T>)
            case continuation(CheckedContinuation<T, any Error>?)
        }

        private let lock = Mutex<State>(.buffer([]))

        /// enqueue an element, or give it back immediately to the iterator if it is waiting for an element
        public func push(_ invocation: T) {

            // if the iterator is waiting for an element on `next()``, give it to it
            // otherwise, enqueue the element
            let maybeContinuation = self.lock.withLock { state -> CheckedContinuation<T, any Error>? in
                switch consume state {
                case .continuation(let continuation):
                    state = .buffer([])
                    return continuation

                case .buffer(var buffer):
                    buffer.append(invocation)
                    state = .buffer(buffer)
                    return nil
                }
            }

            maybeContinuation?.resume(returning: invocation)
        }

        func next() async throws -> T? {
            // exit the async for loop if the task is cancelled
            guard !Task.isCancelled else {
                return nil
            }

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                    let (nextAction, nextError) = self.lock.withLock { state -> (T?, PoolError?) in
                        switch consume state {
                        case .buffer(var buffer):
                            if let first = buffer.popFirst() {
                                state = .buffer(buffer)
                                return (first, nil)
                            } else {
                                state = .continuation(continuation)
                                return (nil, nil)
                            }

                        case .continuation(let previousContinuation):
                            state = .buffer([])
                            return (nil, PoolError(cause: .nextCalledTwice([previousContinuation, continuation])))
                        }
                    }

                    if let nextError,
                        case let .nextCalledTwice(continuations) = nextError.cause
                    {
                        for continuation in continuations { continuation?.resume(throwing: nextError) }
                    } else if let nextAction {
                        continuation.resume(returning: nextAction)
                    }
                }
            } onCancel: {
                self.lock.withLock { state in
                    switch consume state {
                    case .buffer(let buffer):
                        state = .buffer(buffer)
                    case .continuation(let continuation):
                        state = .buffer([])
                        continuation?.resume(throwing: CancellationError())
                    }
                }
            }
        }

        func makeAsyncIterator() -> Pool {
            self
        }

        struct PoolError: Error {
            let cause: Cause
            var message: String {
                switch self.cause {
                case .nextCalledTwice:
                    return "Concurrent invocations to next(). This is not allowed."
                }
            }

            enum Cause {
                case nextCalledTwice([CheckedContinuation<T, any Error>?])
            }
        }
    }
}
#endif