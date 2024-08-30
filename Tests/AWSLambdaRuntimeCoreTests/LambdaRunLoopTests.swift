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

    let mockClient = LambdaMockClient()
    let mockEchoHandler = MockEchoHandler()

    @Test func testRunLoop() async throws {
        let runLoopTask = Task { () in
            try await Lambda.runLoop(
                runtimeClient: self.mockClient,
                handler: self.mockEchoHandler,
                logger: Logger(label: "RunLoopTest")
            )
        }

        let inputEvent = ByteBuffer(string: "Test Invocation Event")
        let response = try await self.mockClient.invoke(event: inputEvent)

        runLoopTask.cancel()

        #expect(response == inputEvent)
    }
}
