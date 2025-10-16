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

#if canImport(FoundationNetworking)
import FoundationNetworking
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

        struct RequestResult {
            let requestIndex: Int
            let statusCode: Int
            let responseBody: String
        }

        let results = try await withThrowingTaskGroup(of: [RequestResult].self) { group in

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
                return try await withThrowingTaskGroup(of: RequestResult.self) { clientGroup in
                    var requestResults: [RequestResult] = []

                    for i in 0..<10 {
                        try await Task.sleep(for: .milliseconds(0))
                        clientGroup.addTask {
                            let (data, response) = try await self.makeInvokeRequest(
                                host: "127.0.0.1",
                                port: customPort,
                                payload: "\"World\(i)\""
                            )
                            let responseBody = String(data: data, encoding: .utf8) ?? ""
                            return RequestResult(
                                requestIndex: i,
                                statusCode: response.statusCode,
                                responseBody: responseBody
                            )
                        }
                    }

                    for try await result in clientGroup {
                        requestResults.append(result)
                    }

                    return requestResults
                }
            }

            // Get the first result (request results) and cancel the runtime
            let first = try await group.next()
            group.cancelAll()
            return first ?? []
        }

        #expect(results.count == 10, "Expected 10 responses")

        // Verify that each request was processed correctly by checking response content
        // Sort results by request index to verify proper execution order
        let sortedResults = results.sorted { $0.requestIndex < $1.requestIndex }
        for (index, result) in sortedResults.enumerated() {
            let expectedResponse = "\"Hello World\(index)\""
            #expect(
                result.responseBody == expectedResponse,
                "Request \(index) response was '\(result.responseBody)', expected '\(expectedResponse)'"
            )
            #expect(
                result.requestIndex == index,
                "Request order mismatch: got index \(result.requestIndex), expected \(index)"
            )
            #expect(
                result.statusCode == 202,
                "Request \(result.requestIndex) returned \(result.statusCode), expected 202 OK"
            )
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
            // Create a custom error since URLError might not be available on Linux
            struct HTTPError: Error {
                let message: String
            }
            throw HTTPError(message: "Bad server response")
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
