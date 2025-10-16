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
import NIOHTTP1
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

@Suite(.serialized)
struct LambdaStreamingTests {

    @Test("Streaming handler sends multiple chunks and completes successfully")
    @available(LambdaSwift 2.0, *)
    func testStreamingHandlerMultipleChunks() async throws {
        let customPort = 8090

        // Set environment variable
        setenv("LOCAL_LAMBDA_PORT", "\(customPort)", 1)
        defer { unsetenv("LOCAL_LAMBDA_PORT") }

        let results = try await withThrowingTaskGroup(of: StreamingTestResult.self) { group in

            // Start the Lambda runtime with streaming handler
            group.addTask {
                struct StreamingTestHandler: StreamingLambdaHandler {
                    func handle(
                        _ event: ByteBuffer,
                        responseWriter: some LambdaResponseStreamWriter,
                        context: LambdaContext
                    ) async throws {
                        // Send multiple chunks with delays to test streaming
                        for i in 1...3 {
                            try await responseWriter.write(ByteBuffer(string: "Chunk \(i)\n"))
                            try await Task.sleep(for: .milliseconds(50))
                        }
                        try await responseWriter.finish()
                    }
                }

                let runtime = LambdaRuntime(
                    handler: StreamingTestHandler()
                )

                try await runtime._run()
                return StreamingTestResult(chunks: [], statusCode: 0, completed: false)
            }

            // Start HTTP client to make streaming request
            group.addTask {
                // Give server time to start
                try await Task.sleep(for: .milliseconds(200))

                return try await self.makeStreamingInvokeRequest(
                    host: "127.0.0.1",
                    port: customPort,
                    payload: "\"test-event\""
                )
            }

            // Get the first result (streaming response) and cancel the runtime
            let first = try await group.next()
            group.cancelAll()
            return first ?? StreamingTestResult(chunks: [], statusCode: 0, completed: false)
        }

        // Verify streaming response
        #expect(results.statusCode == 200, "Expected 200 OK, got \(results.statusCode)")
        #expect(results.completed, "Streaming response should be completed")
        #expect(results.chunks.count >= 1, "Expected at least 1 chunk, got \(results.chunks.count)")

        // The streaming chunks are concatenated in the HTTP response
        let fullResponse = results.chunks.joined()
        let expectedContent = "Chunk 1\nChunk 2\nChunk 3\n"
        #expect(fullResponse == expectedContent, "Response was '\(fullResponse)', expected '\(expectedContent)'")
    }

    @Test("Multiple streaming invocations work correctly")
    @available(LambdaSwift 2.0, *)
    func testMultipleStreamingInvocations() async throws {
        let customPort = 8091

        setenv("LOCAL_LAMBDA_PORT", "\(customPort)", 1)
        defer { unsetenv("LOCAL_LAMBDA_PORT") }

        let results = try await withThrowingTaskGroup(of: [StreamingTestResult].self) { group in

            // Start the Lambda runtime
            group.addTask {
                struct MultiStreamingHandler: StreamingLambdaHandler {
                    func handle(
                        _ event: ByteBuffer,
                        responseWriter: some LambdaResponseStreamWriter,
                        context: LambdaContext
                    ) async throws {
                        let eventString = String(buffer: event)
                        try await responseWriter.write(ByteBuffer(string: "Echo: \(eventString)\n"))
                        try await responseWriter.finish()
                    }
                }

                let runtime = LambdaRuntime(
                    handler: MultiStreamingHandler()
                )

                try await runtime._run()
                return []
            }

            // Make multiple streaming requests
            group.addTask {
                try await Task.sleep(for: .milliseconds(200))

                var results: [StreamingTestResult] = []

                // Make 3 sequential streaming requests
                for i in 1...3 {
                    let result = try await self.makeStreamingInvokeRequest(
                        host: "127.0.0.1",
                        port: customPort,
                        payload: "\"request-\(i)\""
                    )
                    results.append(result)

                    // Small delay between requests
                    try await Task.sleep(for: .milliseconds(100))
                }

                return results
            }

            let first = try await group.next()
            group.cancelAll()
            return first ?? []
        }

        // Verify all requests completed successfully
        #expect(results.count == 3, "Expected 3 responses, got \(results.count)")

        for (index, result) in results.enumerated() {
            #expect(result.statusCode == 200, "Request \(index + 1) returned \(result.statusCode), expected 200")
            #expect(result.completed, "Request \(index + 1) should be completed")
            #expect(result.chunks.count == 1, "Request \(index + 1) should have 1 chunk, got \(result.chunks.count)")

            let expectedContent = "Echo: \"request-\(index + 1)\"\n"
            #expect(result.chunks.first == expectedContent, "Request \(index + 1) content mismatch")
        }
    }

    @Test("Streaming handler with custom headers works correctly")
    @available(LambdaSwift 2.0, *)
    func testStreamingHandlerWithCustomHeaders() async throws {
        let customPort = 8092

        setenv("LOCAL_LAMBDA_PORT", "\(customPort)", 1)
        defer { unsetenv("LOCAL_LAMBDA_PORT") }

        let results = try await withThrowingTaskGroup(of: StreamingTestResult.self) { group in

            group.addTask {
                struct HeaderStreamingHandler: StreamingLambdaHandler {
                    func handle(
                        _ event: ByteBuffer,
                        responseWriter: some LambdaResponseStreamWriter,
                        context: LambdaContext
                    ) async throws {
                        // Send custom headers
                        try await responseWriter.writeStatusAndHeaders(
                            StreamingLambdaStatusAndHeadersResponse(
                                statusCode: 201,
                                headers: [
                                    "Content-Type": "text/plain",
                                    "X-Custom-Header": "streaming-test",
                                ]
                            )
                        )

                        try await responseWriter.write(ByteBuffer(string: "Custom response"))
                        try await responseWriter.finish()
                    }
                }

                let runtime = LambdaRuntime(
                    handler: HeaderStreamingHandler()
                )

                try await runtime._run()
                return StreamingTestResult(chunks: [], statusCode: 0, completed: false)
            }

            group.addTask {
                try await Task.sleep(for: .milliseconds(200))

                return try await self.makeStreamingInvokeRequest(
                    host: "127.0.0.1",
                    port: customPort,
                    payload: "\"header-test\""
                )
            }

            let first = try await group.next()
            group.cancelAll()
            return first ?? StreamingTestResult(chunks: [], statusCode: 0, completed: false)
        }

        // Verify response (custom headers are returned as JSON in the response body)
        #expect(results.statusCode == 200, "Expected 200 OK, got \(results.statusCode)")
        #expect(results.completed, "Streaming response should be completed")
        #expect(results.chunks.count >= 1, "Expected at least 1 chunk, got \(results.chunks.count)")

        // The response contains both the headers JSON and the content
        let fullResponse = results.chunks.joined()
        #expect(fullResponse.contains("\"statusCode\":201"), "Response should contain custom status code")
        #expect(
            fullResponse.contains("\"X-Custom-Header\":\"streaming-test\""),
            "Response should contain custom header"
        )
        #expect(fullResponse.contains("Custom response"), "Response should contain custom content")
    }

    @Test("Streaming handler error handling works correctly")
    @available(LambdaSwift 2.0, *)
    func testStreamingHandlerErrorHandling() async throws {
        let customPort = 8093

        setenv("LOCAL_LAMBDA_PORT", "\(customPort)", 1)
        defer { unsetenv("LOCAL_LAMBDA_PORT") }

        let results = try await withThrowingTaskGroup(of: StreamingTestResult.self) { group in

            group.addTask {
                struct ErrorStreamingHandler: StreamingLambdaHandler {
                    func handle(
                        _ event: ByteBuffer,
                        responseWriter: some LambdaResponseStreamWriter,
                        context: LambdaContext
                    ) async throws {
                        let eventString = String(buffer: event)

                        if eventString.contains("error") {
                            throw TestStreamingError.intentionalError
                        }

                        try await responseWriter.write(ByteBuffer(string: "Success"))
                        try await responseWriter.finish()
                    }
                }

                let runtime = LambdaRuntime(
                    handler: ErrorStreamingHandler()
                )

                try await runtime._run()
                return StreamingTestResult(chunks: [], statusCode: 0, completed: false)
            }

            group.addTask {
                try await Task.sleep(for: .milliseconds(200))

                return try await self.makeStreamingInvokeRequest(
                    host: "127.0.0.1",
                    port: customPort,
                    payload: "\"trigger-error\""
                )
            }

            let first = try await group.next()
            group.cancelAll()
            return first ?? StreamingTestResult(chunks: [], statusCode: 0, completed: false)
        }

        // Verify error response
        #expect(results.statusCode == 500, "Expected 500 Internal Server Error, got \(results.statusCode)")
        #expect(results.completed, "Error response should be completed")
    }

    // MARK: - Helper Methods

    private func makeStreamingInvokeRequest(
        host: String,
        port: Int,
        payload: String
    ) async throws -> StreamingTestResult {
        let url = URL(string: "http://\(host):\(port)/invoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload.data(using: .utf8)
        request.timeoutInterval = 10.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            // On Linux, create a custom error since URLError might not be available
            struct HTTPError: Error {
                let message: String
            }
            throw HTTPError(message: "Bad server response")
        }

        // Parse the streaming response
        let responseString = String(data: data, encoding: .utf8) ?? ""
        let chunks = responseString.isEmpty ? [] : [responseString]

        return StreamingTestResult(
            chunks: chunks,
            statusCode: httpResponse.statusCode,
            completed: true
        )
    }
}

// MARK: - Test Support Types

struct StreamingTestResult {
    let chunks: [String]
    let statusCode: Int
    let completed: Bool
}

enum TestStreamingError: Error {
    case intentionalError
}
