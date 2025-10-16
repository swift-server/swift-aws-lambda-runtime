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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension LambdaRuntimeTests {

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

    @Test("Local server handles rapid concurrent requests without HTTP 400 errors")
    @available(LambdaSwift 2.0, *)
    func testRapidConcurrentRequests() async throws {
        let customPort = 8081

        // Set environment variable
        setenv("LOCAL_LAMBDA_PORT", "\(customPort)", 1)
        defer { unsetenv("LOCAL_LAMBDA_PORT") }

        let results = try await withThrowingTaskGroup(of: [Int].self) { group in

            // Start the Lambda runtime with local server
            group.addTask {
                let runtime = LambdaRuntime { (event: String, context: LambdaContext) in
                    try await Task.sleep(for: .milliseconds(100))
                    return "Hello \(event)"
                }

                // Start runtime (this will block until cancelled)
                try await runtime._run()
                return []
            }

            // Start HTTP client to make rapid requests
            group.addTask {
                // Give server time to start
                try await Task.sleep(for: .milliseconds(200))

                // Make 10 rapid concurrent POST requests to /invoke
                return try await withThrowingTaskGroup(of: Int.self) { clientGroup in
                    var statuses: [Int] = []

                    for i in 0..<10 {
                        try await Task.sleep(for: .milliseconds(0))
                        clientGroup.addTask {
                            let (_, response) = try await self.makeInvokeRequest(
                                host: "127.0.0.1",
                                port: customPort,
                                payload: "\"World\(i)\""
                            )
                            return response.statusCode
                        }
                    }

                    for try await status in clientGroup {
                        statuses.append(status)
                    }

                    return statuses
                }
            }

            // Get the first result (HTTP statuses) and cancel the runtime
            let first = try await group.next()
            group.cancelAll()
            return first ?? []
        }

        // Verify all requests returned 200 OK (no HTTP 400 errors)
        #expect(results.count == 10, "Expected 10 responses")
        for (index, status) in results.enumerated() {
            #expect(status == 202, "Request \(index) returned \(status), expected 202 OK")
        }
    }

    private func makeInvokeRequest(host: String, port: Int, payload: String) async throws -> (Data, HTTPURLResponse) {
        let url = URL(string: "http://\(host):\(port)/invoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload.data(using: .utf8)
        request.timeoutInterval = 10.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, httpResponse)
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
