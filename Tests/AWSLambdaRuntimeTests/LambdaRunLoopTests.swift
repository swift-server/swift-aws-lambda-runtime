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

import Logging
import NIOCore
import Testing

@testable import AWSLambdaRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite
#if swift(>=6.1)
@available(LambdaSwift 2.0, *)
#endif
struct LambdaRunLoopTests {
    struct MockEchoHandler: StreamingLambdaHandler {
        func handle(
            _ event: ByteBuffer,
            responseWriter: some LambdaResponseStreamWriter,
            context: LambdaContext
        ) async throws {
            context.logger.info("Test")
            try await responseWriter.writeAndFinish(event)
        }
    }

    struct FailingHandler: StreamingLambdaHandler {
        func handle(
            _ event: ByteBuffer,
            responseWriter: some LambdaResponseStreamWriter,
            context: LambdaContext
        ) async throws {
            context.logger.info("Test")
            throw LambdaError.handlerError
        }
    }

    let mockClient = MockLambdaClient()
    let mockEchoHandler = MockEchoHandler()
    let failingHandler = FailingHandler()

    @Test func testRunLoop() async throws {
        let inputEvent = ByteBuffer(string: "Test Invocation Event")

        try await withThrowingTaskGroup(of: Void.self) { group in
            let logStore = CollectEverythingLogHandler.LogStore()
            group.addTask {
                try await Lambda.runLoop(
                    runtimeClient: self.mockClient,
                    handler: self.mockEchoHandler,
                    logger: Logger(
                        label: "RunLoopTest",
                        factory: { _ in CollectEverythingLogHandler(logStore: logStore) }
                    )
                )
            }

            let requestID = UUID().uuidString
            let response = try await self.mockClient.invoke(event: inputEvent, requestID: requestID)
            #expect(response == inputEvent)
            logStore.assertContainsLog("Test", ("aws-request-id", .exactMatch(requestID)))

            group.cancelAll()
        }
    }

    @Test func testRunLoopError() async throws {
        let inputEvent = ByteBuffer(string: "Test Invocation Event")

        await withThrowingTaskGroup(of: Void.self) { group in
            let logStore = CollectEverythingLogHandler.LogStore()
            group.addTask {
                try await Lambda.runLoop(
                    runtimeClient: self.mockClient,
                    handler: self.failingHandler,
                    logger: Logger(
                        label: "RunLoopTest",
                        factory: { _ in CollectEverythingLogHandler(logStore: logStore) }
                    )
                )
            }

            let requestID = UUID().uuidString
            await #expect(
                throws: LambdaError.handlerError,
                performing: {
                    try await self.mockClient.invoke(event: inputEvent, requestID: requestID)
                }
            )
            logStore.assertContainsLog("Test", ("aws-request-id", .exactMatch(requestID)))

            group.cancelAll()
        }
    }
}
