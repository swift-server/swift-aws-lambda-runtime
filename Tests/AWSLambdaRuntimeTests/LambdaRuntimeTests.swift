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

import Foundation
import Logging
import NIOCore
import Synchronization
import Testing

@testable import AWSLambdaRuntime

@Suite("LambdaRuntimeTests", .serialized)
struct LambdaRuntimeTests {

    @Test("LambdaRuntime can only be run once")
    func testLambdaRuntimerunOnce() async throws {

        // First runtime
        let runtime1 = LambdaRuntime(
            handler: MockHandler(),
            eventLoop: Lambda.defaultEventLoop,
            logger: Logger(label: "LambdaRuntimeTests.Runtime1")
        )

        // Second runtime
        let runtime2 = LambdaRuntime(
            handler: MockHandler(),
            eventLoop: Lambda.defaultEventLoop,
            logger: Logger(label: "LambdaRuntimeTests.Runtime2")
        )

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in

            // start the first runtime
            taskGroup.addTask {
                // will throw LambdaRuntimeError when run() is called second or ChannelError when cancelled
                try await runtime1.run()
            }

            // wait a small amount to ensure runtime1 task is started
            try await Task.sleep(for: .seconds(0.5))

            // start the second runtime
            taskGroup.addTask {
                // will throw LambdaRuntimeError when run() is called second or ChannelError when cancelled
                try await runtime2.run()
            }

            // get the first result (should throw a LambdaRuntimeError)
            try await #require(throws: LambdaRuntimeError.self) {
                try await taskGroup.next()
            }

            // cancel the group to end the test
            taskGroup.cancelAll()

        }
    }
    @Test("run() must be cancellable")
    func testLambdaRuntimeCancellable() async throws {

        let logger = Logger(label: "LambdaRuntimeTests.RuntimeCancellable")
        // create a runtime
        let runtime = LambdaRuntime(
            handler: MockHandler(),
            eventLoop: Lambda.defaultEventLoop,
            logger: logger
        )

        // Running the runtime with structured concurrency
        // Task group returns when all tasks are completed.
        // Even cancelled tasks must cooperatlivly complete
        await #expect(throws: Never.self) {
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                taskGroup.addTask {
                    logger.trace("--- launching runtime ----")
                    try await runtime.run()
                }

                // Add a timeout task to the group
                taskGroup.addTask {
                    logger.trace("--- launching timeout task ----")
                    try await Task.sleep(for: .seconds(5))
                    if Task.isCancelled { return }
                    logger.trace("--- throwing timeout error ----")
                    throw TestError.timeout  // Fail the test if the timeout triggers
                }

                do {
                    // Wait for the runtime to start
                    logger.trace("--- waiting for runtime to start ----")
                    try await Task.sleep(for: .seconds(1))

                    // Cancel all tasks, this should not throw an error
                    // and should allow the runtime to complete gracefully
                    logger.trace("--- cancel all tasks ----")
                    taskGroup.cancelAll()  // Cancel all tasks
                } catch {
                    logger.error("--- catch an error: \(error)")
                    throw error  // Propagate the error to fail the test
                }
            }
        }

    }
}

struct MockHandler: StreamingLambdaHandler {
    mutating func handle(
        _ event: NIOCore.ByteBuffer,
        responseWriter: some AWSLambdaRuntime.LambdaResponseStreamWriter,
        context: AWSLambdaRuntime.LambdaContext
    ) async throws {

    }
}

// Define a custom error for timeout
enum TestError: Error, CustomStringConvertible {
    case timeout

    var description: String {
        switch self {
        case .timeout:
            return "Test timed out waiting for the task to complete."
        }
    }
}
