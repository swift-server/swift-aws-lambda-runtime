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

import AWSLambdaRuntime
import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct SendNumbersWithPause: StreamingLambdaHandler {
    func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {

        // Send HTTP status code and headers before streaming the response body
        try await responseWriter.writeStatusAndHeaders(
            StreamingLambdaStatusAndHeadersResponse(
                statusCode: 200,
                headers: [
                    "Content-Type": "text/plain",
                    "x-my-custom-header": "streaming-example",
                ],
                multiValueHeaders: [
                    "Set-Cookie": ["session=abc123", "theme=dark"]
                ]
            )
        )

        // Stream numbers with pauses to demonstrate streaming functionality
        for i in 1...10 {
            // Send partial data
            try await responseWriter.write(ByteBuffer(string: "Number: \(i)\n"))
            // Perform some long asynchronous work to simulate processing
            try await Task.sleep(for: .milliseconds(1000))
        }

        // Send final message
        try await responseWriter.write(ByteBuffer(string: "Streaming complete!\n"))

        // All data has been sent. Close off the response stream.
        try await responseWriter.finish()
    }
}

// Example of a more complex streaming handler that demonstrates different response scenarios
struct ConditionalStreamingHandler: StreamingLambdaHandler {
    func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {

        // Parse the event to determine response type
        let eventString = String(buffer: event)
        let shouldError = eventString.contains("error")

        if shouldError {
            // Send error response with appropriate status code
            try await responseWriter.writeStatusAndHeaders(
                StreamingLambdaStatusAndHeadersResponse(
                    statusCode: 400,
                    headers: [
                        "Content-Type": "application/json",
                        "x-error-type": "client-error",
                    ]
                )
            )

            try await responseWriter.writeAndFinish(
                ByteBuffer(string: #"{"error": "Bad request", "message": "Error requested in input"}"#)
            )
        } else {
            // Send successful response with streaming data
            try await responseWriter.writeStatusAndHeaders(
                StreamingLambdaStatusAndHeadersResponse(
                    statusCode: 200,
                    headers: [
                        "Content-Type": "application/json",
                        "Cache-Control": "no-cache",
                    ]
                )
            )

            // Stream JSON array elements
            try await responseWriter.write(ByteBuffer(string: "["))

            for i in 1...5 {
                if i > 1 {
                    try await responseWriter.write(ByteBuffer(string: ","))
                }
                try await responseWriter.write(
                    ByteBuffer(string: #"{"id": \#(i), "timestamp": "\#(Date().timeIntervalSince1970)"}"#)
                )
                try await Task.sleep(for: .milliseconds(500))
            }

            try await responseWriter.write(ByteBuffer(string: "]"))
            try await responseWriter.finish()
        }
    }
}

// Use the simple example by default
let runtime = LambdaRuntime(handler: SendNumbersWithPause())
try await runtime.run()
