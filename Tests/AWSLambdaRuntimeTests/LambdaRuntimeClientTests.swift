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
import NIOPosix
import Testing

import struct Foundation.UUID

@testable import AWSLambdaRuntime

@Suite
struct LambdaRuntimeClientTests {

    let logger = {
        var logger = Logger(label: "NewLambdaClientRuntimeTest")
        // logger.logLevel = .trace
        return logger
    }()

    @Test
    func testSimpleInvocations() async throws {
        struct HappyBehavior: LambdaServerBehavior {
            let requestId = UUID().uuidString
            let event = "hello"

            func getInvocation() -> GetInvocationResult {
                .success((self.requestId, self.event))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                #expect(self.requestId == requestId)
                #expect(self.event == response)
                return .success(())
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                Issue.record("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                Issue.record("should not report init error")
                return .failure(.internalServerError)
            }
        }

        try await withMockServer(behaviour: HappyBehavior()) { port in
            let configuration = LambdaRuntimeClient.Configuration(ip: "127.0.0.1", port: port)

            try await LambdaRuntimeClient.withRuntimeClient(
                configuration: configuration,
                eventLoop: NIOSingletons.posixEventLoopGroup.next(),
                logger: self.logger
            ) { runtimeClient in
                do {
                    let (invocation, writer) = try await runtimeClient.nextInvocation()
                    let expected = ByteBuffer(string: "hello")
                    #expect(invocation.event == expected)
                    try await writer.writeAndFinish(expected)
                }

                do {
                    let (invocation, writer) = try await runtimeClient.nextInvocation()
                    let expected = ByteBuffer(string: "hello")
                    #expect(invocation.event == expected)
                    try await writer.write(ByteBuffer(string: "h"))
                    try await writer.write(ByteBuffer(string: "e"))
                    try await writer.write(ByteBuffer(string: "l"))
                    try await writer.write(ByteBuffer(string: "l"))
                    try await writer.write(ByteBuffer(string: "o"))
                    try await writer.finish()
                }
            }
        }
    }

    @Test
    func testCancellation() async throws {
        struct HappyBehavior: LambdaServerBehavior {
            let requestId = UUID().uuidString
            let event = "hello"

            func getInvocation() -> GetInvocationResult {
                .success((self.requestId, self.event))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                #expect(self.requestId == requestId)
                #expect(self.event == response)
                return .success(())
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                Issue.record("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                Issue.record("should not report init error")
                return .failure(.internalServerError)
            }
        }

        try await withMockServer(behaviour: HappyBehavior()) { port in
            try await LambdaRuntimeClient.withRuntimeClient(
                configuration: .init(ip: "127.0.0.1", port: port),
                eventLoop: NIOSingletons.posixEventLoopGroup.next(),
                logger: self.logger
            ) { runtimeClient in
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        while true {
                            let (_, writer) = try await runtimeClient.nextInvocation()
                            // Wrap this is a task so cancellation isn't propagated to the write calls
                            try await Task {
                                try await writer.write(ByteBuffer(string: "hello"))
                                try await writer.finish()
                            }.value
                        }
                    }
                    // wait a small amount to ensure we are waiting for continuation
                    try await Task.sleep(for: .milliseconds(100))
                    group.cancelAll()
                }
            }
        }
    }
}
