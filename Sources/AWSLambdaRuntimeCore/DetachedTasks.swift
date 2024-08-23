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
actor DetachedTasksContainer: Sendable {

    struct Context: Sendable {
        let eventLoop: EventLoop
        let logger: Logger
    }
    
    private var context: Context
    private var storage: [RegistrationKey: EventLoopFuture<Void>] = [:]

    init(context: Context) {
        self.context = context
    }

    /// Adds a detached async task.
    ///
    /// - Parameters:
    ///   - name: The name of the task.
    ///   - task: The async task to execute.
    /// - Returns: A `RegistrationKey` for the registered task.
    func detached(task: @Sendable @escaping () async -> Void) {
        let key = RegistrationKey()
        let promise = context.eventLoop.makePromise(of: Void.self)
        promise.completeWithTask(task)
        let task = promise.futureResult.always { [weak self] result in
            guard let self else { return }
            Task {
                await self.removeTask(forKey: key)
            }
        }
        self.storage[key] = task
    }
    
    func removeTask(forKey key: RegistrationKey) {
        self.storage.removeValue(forKey: key)
    }

    /// Awaits all registered tasks to complete.
    ///
    /// - Returns: An `EventLoopFuture<Void>` that completes when all tasks have finished.
    func awaitAll() -> EventLoopFuture<Void> {
        let tasks = storage.values
        if tasks.isEmpty {
            return context.eventLoop.makeSucceededVoidFuture()
        } else {
            let context = context
            return EventLoopFuture.andAllComplete(Array(tasks), on: context.eventLoop).flatMap { [weak self] in
                guard let self else {
                    return context.eventLoop.makeSucceededFuture(())
                }
                let promise = context.eventLoop.makePromise(of: Void.self)
                promise.completeWithTask {
                    try await self.awaitAll().get()
                }
                return promise.futureResult
            }
        }
    }
}

extension DetachedTasksContainer {
    /// Lambda detached task registration key.
    struct RegistrationKey: Hashable, CustomStringConvertible, Sendable {
        var value: String

        init() {
            // UUID basically
            self.value = UUID().uuidString
        }

        var description: String {
            self.value
        }
    }
}
