//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOConcurrencyHelpers
import NIOCore

extension Lambda {
    /// Lambda terminator.
    /// Utility to manage the lambda shutdown sequence.
    public final class Terminator {
        public typealias Handler = (EventLoop) -> EventLoopFuture<Void>
        public typealias RegistrationKey = String

        private var storage: Storage

        public init() {
            self.storage = Storage()
        }

        /// Register a shutdown handler with the terminator
        ///
        /// - parameters:
        ///     - name: Display name for logging purposes
        ///     - handler: The shutdown handler to call when terminating the Lambda.
        ///             Shutdown handlers are called in the reverse order of being registered.
        ///
        /// - Returns: A `RegistrationKey` that can be used to de-register the handler when its no longer needed.
        @discardableResult
        public func register(name: String, handler: @escaping Handler) -> RegistrationKey {
            let key = LambdaRequestID().uuidString // UUID basically
            self.storage.add(key: key, name: name, handler: handler)
            return key
        }

        /// De-register a shutdown handler with the terminator
        ///
        /// - parameters:
        ///     - key: A `RegistrationKey` obtained from calling the register API.
        public func deregister(_ key: RegistrationKey) {
            self.storage.remove(key)
        }

        /// Begin the termination cycle
        /// Shutdown handlers are called in the reverse order of being registered.
        ///
        /// - parameters:
        ///     - eventLoop: The `EventLoop` to run the termination on.
        ///
        /// - Returns: An`EventLoopFuture` with the result of the termination cycle.
        internal func terminate(eventLoop: EventLoop) -> EventLoopFuture<Void> {
            func terminate(_ iterator: IndexingIterator<[(name: String, handler: Handler)]>, errors: [Error], promise: EventLoopPromise<Void>) {
                var iterator = iterator
                guard let handler = iterator.next()?.handler else {
                    if errors.isEmpty {
                        return promise.succeed(())
                    } else {
                        return promise.fail(TerminationError(underlying: errors))
                    }
                }
                handler(eventLoop).whenComplete { result in
                    var errors = errors
                    if case .failure(let error) = result {
                        errors.append(error)
                    }
                    return terminate(iterator, errors: errors, promise: promise)
                }
            }

            // terminate in cascading, reverse order
            let promise = eventLoop.makePromise(of: Void.self)
            terminate(self.storage.handlers.reversed().makeIterator(), errors: [], promise: promise)
            return promise.futureResult
        }
    }

    private final class Storage {
        private let lock: Lock
        private var index: [String]
        private var map: [String: (name: String, handler: Terminator.Handler)]

        public init() {
            self.lock = .init()
            self.index = []
            self.map = [:]
        }

        func add(key: String, name: String, handler: @escaping Terminator.Handler) {
            self.lock.withLock {
                self.index.append(key)
                self.map[key] = (name: name, handler: handler)
            }
        }

        func remove(_ key: String) {
            self.lock.withLock {
                self.index = self.index.filter { $0 != key }
                self.map[key] = nil
            }
        }

        var handlers: [(name: String, handler: Terminator.Handler)] {
            self.lock.withLock {
                self.index.compactMap { self.map[$0] }
            }
        }
    }

    struct TerminationError: Error {
        let underlying: [Error]
    }
}

extension Result {
    fileprivate var error: Error? {
        switch self {
        case .failure(let error):
            return error
        case .success:
            return .none
        }
    }
}
