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
import Foundation
import NIOConcurrencyHelpers
import NIOCore
import Logging

/// A container that allows tasks to finish after a synchronous invocation
/// has produced its response.
public final class DetachedTasksContainer {

    struct Context {
        let eventLoop: EventLoop
        let logger: Logger
    }
    
    private var context: Context
    private var storage: Storage

    init(context: Context) {
        self.storage = Storage()
        self.context = context
    }

    /// Adds a detached task that runs on the given event loop.
    ///
    /// - Parameters:
    ///   - name: The name of the task.
    ///   - task: The task to execute. It receives an `EventLoop` and returns an `EventLoopFuture<Void>`.
    /// - Returns: A `RegistrationKey` for the registered task.
    @discardableResult
    public func detached(name: String, task: @escaping (EventLoop) -> EventLoopFuture<Void>) -> RegistrationKey {
        let key = RegistrationKey()
        let task = task(context.eventLoop).always { _ in
            self.storage.remove(key)
        }
        self.storage.add(key: key, name: name, task: task)
        return key
    }
    
    /// Adds a detached async task.
    ///
    /// - Parameters:
    ///   - name: The name of the task.
    ///   - task: The async task to execute.
    /// - Returns: A `RegistrationKey` for the registered task.
    @discardableResult
    public func detached(name: String, task: @Sendable @escaping () async throws -> Void) -> RegistrationKey {
        let key = RegistrationKey()
        let promise = context.eventLoop.makePromise(of: Void.self)
        promise.completeWithTask(task)
        let task = promise.futureResult.always { result in
            switch result {
            case .success:
                break
            case .failure(let failure):
                self.context.logger.warning(
                    "Execution of detached task failed with error.",
                    metadata: [
                        "taskName": "\(name)",
                        "error": "\(failure)"
                    ]
                )
            }
            self.storage.remove(key)
        }
        self.storage.add(key: key, name: name, task: task)
        return key
    }

    /// Informs the runtime that the specified task should not be awaited anymore.
    ///
    /// - Warning: This method does not actually stop the execution of the
    ///   detached task, it only prevents the runtime from waiting for it before
    ///   `/next` is invoked.
    ///
    /// - Parameter key: The `RegistrationKey` of the task to cancel.
    public func unsafeCancel(_ key: RegistrationKey) {
        // To discuss:
        // Canceling the execution doesn't seem to be an easy
        // task https://github.com/apple/swift-nio/issues/2087
        //
        // While removing the handler will allow the runtime
        // to invoke `/next` without actually awaiting for the
        // task to complete, it does not actually cancel
        // the execution of the dispatched task.
        // Since this is a bit counter-intuitive, we might not
        // want this method to exist at all.
        self.storage.remove(key)
    }

    /// Awaits all registered tasks to complete.
    ///
    /// - Returns: An `EventLoopFuture<Void>` that completes when all tasks have finished.
    internal func awaitAll() -> EventLoopFuture<Void> {
        let tasks = storage.tasks
        if tasks.isEmpty {
            return context.eventLoop.makeSucceededVoidFuture()
        } else {
            return EventLoopFuture.andAllComplete(tasks.map(\.value.task), on: context.eventLoop).flatMap {
                self.awaitAll()
            }
        }
    }
}

extension DetachedTasksContainer {
    /// Lambda detached task registration key.
    public struct RegistrationKey: Hashable, CustomStringConvertible {
        var value: String

        init() {
            // UUID basically
            self.value = UUID().uuidString
        }

        public var description: String {
            self.value
        }
    }
}

extension DetachedTasksContainer {
    fileprivate final class Storage {
        private let lock: NIOLock
        
        private var map: [RegistrationKey: (name: String, task: EventLoopFuture<Void>)]

        init() {
            self.lock = .init()
            self.map = [:]
        }

        func add(key: RegistrationKey, name: String, task: EventLoopFuture<Void>) {
            self.lock.withLock {
                self.map[key] = (name: name, task: task)
            }
        }

        func remove(_ key: RegistrationKey) {
            self.lock.withLock {
                self.map[key] = nil
            }
        }

        var tasks: [RegistrationKey: (name: String, task: EventLoopFuture<Void>)] {
            self.lock.withLock {
                self.map
            }
        }
    }
}

// Ideally this would not be @unchecked Sendable, but Sendable checks do not understand locks
// We can transition this to an actor once we drop support for older Swift versions
extension DetachedTasksContainer: @unchecked Sendable {}
extension DetachedTasksContainer.Storage: @unchecked Sendable {}
extension DetachedTasksContainer.RegistrationKey: Sendable {}
