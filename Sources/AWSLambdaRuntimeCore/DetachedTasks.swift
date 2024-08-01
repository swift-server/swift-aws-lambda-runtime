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
    public func detached(name: String, task: @Sendable @escaping () async -> Void) -> RegistrationKey {
        let key = RegistrationKey()
        let promise = context.eventLoop.makePromise(of: Void.self)
        promise.completeWithTask(task)
        let task = promise.futureResult.always { result in
            self.storage.remove(key)
        }
        self.storage.add(key: key, name: name, task: task)
        return key
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
