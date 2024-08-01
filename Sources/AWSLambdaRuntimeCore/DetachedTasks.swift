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
final class DetachedTasksContainer {

    struct Context {
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
    @discardableResult
    func detached(task: @Sendable @escaping () async -> Void) -> RegistrationKey {
        let key = RegistrationKey()
        let promise = context.eventLoop.makePromise(of: Void.self)
        promise.completeWithTask(task)
        let task = promise.futureResult.always { result in
            self.storage.removeValue(forKey: key)
        }
        self.storage[key] = task
        return key
    }

    /// Awaits all registered tasks to complete.
    ///
    /// - Returns: An `EventLoopFuture<Void>` that completes when all tasks have finished.
    internal func awaitAll() -> EventLoopFuture<Void> {
        let tasks = storage.values
        if tasks.isEmpty {
            return context.eventLoop.makeSucceededVoidFuture()
        } else {
            return EventLoopFuture.andAllComplete(Array(tasks), on: context.eventLoop).flatMap {
                self.awaitAll()
            }
        }
    }
}

extension DetachedTasksContainer {
    /// Lambda detached task registration key.
    struct RegistrationKey: Hashable, CustomStringConvertible {
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

// Ideally this would not be @unchecked Sendable, but Sendable checks do not understand locks
// We can transition this to an actor once we drop support for older Swift versions
extension DetachedTasksContainer: @unchecked Sendable {}
extension DetachedTasksContainer.RegistrationKey: Sendable {}
