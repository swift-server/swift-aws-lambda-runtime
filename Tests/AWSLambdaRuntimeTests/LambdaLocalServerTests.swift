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

import Logging
import NIOCore
import NIOPosix
import Testing

@testable import AWSLambdaRuntime

// serialized to start only one runtime at a time
@Suite(.serialized)
struct LambdaLocalServerTest {
    @Test("Local server respects LOCAL_LAMBDA_PORT environment variable")
    @available(LambdaSwift 2.0, *)
    func testLocalServerCustomPort() async throws {
        let customPort = 8080

        // Set environment variable
        setenv("LOCAL_LAMBDA_PORT", "\(customPort)", 1)
        defer { unsetenv("LOCAL_LAMBDA_PORT") }

        let result = try? await withThrowingTaskGroup(of: Bool.self) { group in

            // start a local lambda + local server on custom port
            group.addTask {
                // Create a simple handler
                struct TestHandler: StreamingLambdaHandler {
                    func handle(
                        _ event: ByteBuffer,
                        responseWriter: some LambdaResponseStreamWriter,
                        context: LambdaContext
                    ) async throws {
                        try await responseWriter.write(ByteBuffer(string: "test"))
                        try await responseWriter.finish()
                    }
                }

                // create the Lambda Runtime
                let runtime = LambdaRuntime(
                    handler: TestHandler(),
                    logger: Logger(label: "test", factory: { _ in SwiftLogNoOpLogHandler() })
                )

                // Start runtime
                try await runtime._run()

                // we reach this line when the group is cancelled
                return false
            }

            // start a client to check if something responds on the custom port
            group.addTask {
                // Give server time to start
                try await Task.sleep(for: .milliseconds(100))

                // Verify server is listening on custom port
                return try await isPortResponding(host: "127.0.0.1", port: customPort)
            }

            let first = try await group.next()
            group.cancelAll()
            return first ?? false

        }

        #expect(result == true)
    }

    private func isPortResponding(host: String, port: Int) async throws -> Bool {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let bootstrap = ClientBootstrap(group: group)

        do {
            let channel = try await bootstrap.connect(host: host, port: port).get()
            try await channel.close().get()
            try await group.shutdownGracefully()
            return true
        } catch {
            try await group.shutdownGracefully()
            return false
        }
    }
}
