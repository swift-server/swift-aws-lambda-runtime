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

@Suite("LambdaRuntimeTests")
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
                // ChannelError will be thrown when we cancel the task group
                await #expect(throws: ChannelError.self) {
                    try await runtime1.run()
                }
            }

            // wait a small amount to ensure runtime1 task is started
            try await Task.sleep(for: .seconds(1))

            // Running the second runtime should trigger LambdaRuntimeError
            await #expect(throws: LambdaRuntimeError.self) {
                try await runtime2.run()
            }

            // cancel runtime 1 / task 1
            taskGroup.cancelAll()
        }

        // Running the second runtime should work now
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask {
                // ChannelError will be thrown when we cancel the task group
                await #expect(throws: ChannelError.self) {
                    try await runtime2.run()
                }
            }

            // Set timeout and cancel the runtime 2
            try await Task.sleep(for: .seconds(2))
            taskGroup.cancelAll()
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
