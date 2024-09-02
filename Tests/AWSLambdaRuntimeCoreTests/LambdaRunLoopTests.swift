//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
import Testing

@testable import AWSLambdaRuntimeCore

@Suite
struct LambdaRunLoopTests {
    struct MockEchoHandler: StreamingLambdaHandler {
        func handle(
            _ event: ByteBuffer,
            responseWriter: some LambdaResponseStreamWriter,
            context: NewLambdaContext
        ) async throws {
            try await responseWriter.writeAndFinish(event)
        }
    }

    struct FailingHandler: StreamingLambdaHandler {
        func handle(
            _ event: ByteBuffer,
            responseWriter: some LambdaResponseStreamWriter,
            context: NewLambdaContext
        ) async throws {
            throw LambdaError.handlerError
        }
    }

    let mockClient = LambdaMockClient()
    let mockEchoHandler = MockEchoHandler()
    let failingHandler = FailingHandler()

    @Test func testRunLoop() async throws {
        let inputEvent = ByteBuffer(string: "Test Invocation Event")

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Lambda.runLoop(
                    runtimeClient: self.mockClient,
                    handler: self.mockEchoHandler,
                    logger: Logger(label: "RunLoopTest")
                )
            }

            let response = try await self.mockClient.invoke(event: inputEvent)
            #expect(response == inputEvent)

            group.cancelAll()
        }
    }

    @Test func testRunLoopError() async throws {
        let inputEvent = ByteBuffer(string: "Test Invocation Event")

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Lambda.runLoop(
                    runtimeClient: self.mockClient,
                    handler: self.failingHandler,
                    logger: Logger(label: "RunLoopTest")
                )
            }

            await #expect(
                throws: LambdaError.handlerError,
                performing: {
                    try await self.mockClient.invoke(event: inputEvent)
                }
            )

            group.cancelAll()
        }
    }
}
