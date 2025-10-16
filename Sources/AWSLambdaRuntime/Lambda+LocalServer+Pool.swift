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
            // FIFO waiting (for invocations)
            case waitingForAny(CheckedContinuation<T, any Error>)
            // RequestId-based waiting (for responses)
            case waitingForSpecific([String: CheckedContinuation<T, any Error>])
        }

        private let lock = Mutex<State>(.buffer([]))

        /// enqueue an element, or give it back immediately to the iterator if it is waiting for an element
        public func push(_ item: T) {
            let continuationToResume = self.lock.withLock { state -> CheckedContinuation<T, any Error>? in
                switch consume state {
                case .buffer(var buffer):
                    buffer.append(item)
                    state = .buffer(buffer)
                    return nil

                case .waitingForAny(let continuation):
                    // Someone is waiting for any item (FIFO)
                    state = .buffer([])
                    return continuation

                case .waitingForSpecific(var continuations):
                    // Check if this item matches any waiting continuation
                    if let response = item as? LocalServerResponse,
                        let requestId = response.requestId,
                        let continuation = continuations.removeValue(forKey: requestId)
                    {
                        // Found a matching continuation
                        if continuations.isEmpty {
                            state = .buffer([])
                        } else {
                            state = .waitingForSpecific(continuations)
                        }
                        return continuation
                    } else {
                        // No matching continuation, add to buffer
                        var buffer = Deque<T>()
                        buffer.append(item)
                        state = .buffer(buffer)
                        return nil
                    }
                }
            }

            // Resume continuation outside the lock to prevent potential deadlocks
            continuationToResume?.resume(returning: item)
        }

        /// Unified next() method that handles both FIFO and requestId-specific waiting
        private func _next(for requestId: String?) async throws -> T {
            // exit if the task is cancelled
            guard !Task.isCancelled else {
                throw CancellationError()
            }

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                    let nextAction: Result<T, PoolError>? = self.lock.withLock { state -> Result<T, PoolError>? in
                        switch consume state {
                        case .buffer(var buffer):
                            if let requestId = requestId {
                                // Look for oldest (first) item for this requestId in buffer
                                if let index = buffer.firstIndex(where: { item in
                                    if let response = item as? LocalServerResponse {
                                        return response.requestId == requestId
                                    }
                                    return false
                                }) {
                                    let item = buffer.remove(at: index)
                                    state = .buffer(buffer)
                                    return .success(item)
                                } else {
                                    // No matching item, wait for it
                                    var continuations: [String: CheckedContinuation<T, any Error>] = [:]
                                    continuations[requestId] = continuation
                                    state = .waitingForSpecific(continuations)
                                    return nil
                                }
                            } else {
                                // FIFO mode - take first item
                                if let first = buffer.popFirst() {
                                    state = .buffer(buffer)
                                    return .success(first)
                                } else {
                                    state = .waitingForAny(continuation)
                                    return nil
                                }
                            }

                        case .waitingForAny(let previousContinuation):
                            if requestId == nil {
                                // Another FIFO call while already waiting
                                state = .buffer([])
                                return .failure(PoolError(cause: .nextCalledTwice(previousContinuation)))
                            } else {
                                // Can't mix FIFO and specific waiting
                                state = .waitingForAny(previousContinuation)
                                return .failure(PoolError(cause: .mixedWaitingModes))
                            }

                        case .waitingForSpecific(var continuations):
                            if let requestId = requestId {
                                if continuations[requestId] != nil {
                                    // Already waiting for this requestId
                                    state = .waitingForSpecific(continuations)
                                    return .failure(PoolError(cause: .duplicateRequestIdWait(requestId)))
                                } else {
                                    continuations[requestId] = continuation
                                    state = .waitingForSpecific(continuations)
                                    return nil
                                }
                            } else {
                                // Can't mix FIFO and specific waiting
                                state = .waitingForSpecific(continuations)
                                return .failure(PoolError(cause: .mixedWaitingModes))
                            }
                        }
                    }

                    switch nextAction {
                    case .success(let item):
                        continuation.resume(returning: item)
                    case .failure(let error):
                        if case let .nextCalledTwice(prevContinuation) = error.cause {
                            prevContinuation.resume(throwing: error)
                        }
                        continuation.resume(throwing: error)
                    case .none:
                        // do nothing - continuation is stored in state
                        break
                    }
                }
            } onCancel: {
                // Ensure we properly handle cancellation by checking if we have a stored continuation
                let continuationsToCancel = self.lock.withLock { state -> [String: CheckedContinuation<T, any Error>] in
                    switch consume state {
                    case .buffer(let buffer):
                        state = .buffer(buffer)
                        return [:]
                    case .waitingForAny(let continuation):
                        state = .buffer([])
                        return ["": continuation]  // Use empty string as key for single continuation
                    case .waitingForSpecific(let continuations):
                        state = .buffer([])
                        return continuations
                    }
                }

                // Resume all continuations outside the lock to avoid potential deadlocks
                for continuation in continuationsToCancel.values {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        /// Simple FIFO next() method - used by AsyncIteratorProtocol
        func next() async throws -> T? {
            try await _next(for: nil)
        }

        /// RequestId-specific next() method for LocalServerResponse - NOT part of AsyncIteratorProtocol
        func next(for requestId: String) async throws -> T {
            try await _next(for: requestId)
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
                case .duplicateRequestIdWait(let requestId):
                    return "Already waiting for requestId: \(requestId)"
                case .mixedWaitingModes:
                    return "Cannot mix FIFO waiting (next()) with specific waiting (next(for:))"
                }
            }

            enum Cause {
                case nextCalledTwice(CheckedContinuation<T, any Error>)
                case duplicateRequestIdWait(String)
                case mixedWaitingModes
            }
        }
    }
}
#endif
