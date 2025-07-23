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

// Define your input event structure
struct StreamingRequest: Decodable {
    let count: Int
    let message: String
    let delayMs: Int?

    // Provide default values for optional fields
    var delay: Int {
        delayMs ?? 500
    }
}

// Use the new streaming handler with JSON decoding
let runtime = LambdaRuntime { (event: StreamingRequest, responseWriter, context: LambdaContext) in
    context.logger.info("Received request to send \(event.count) messages: '\(event.message)'")

    // Validate input
    guard event.count > 0 && event.count <= 100 else {
        let errorMessage = "Count must be between 1 and 100, got: \(event.count)"
        context.logger.error("\(errorMessage)")
        try await responseWriter.writeAndFinish(ByteBuffer(string: "Error: \(errorMessage)\n"))
        return
    }

    // Stream the messages
    for i in 1...event.count {
        let response = "[\(Date().ISO8601Format())] Message \(i)/\(event.count): \(event.message)\n"
        try await responseWriter.write(ByteBuffer(string: response))

        // Optional delay between messages
        if event.delay > 0 {
            try await Task.sleep(for: .milliseconds(event.delay))
        }
    }

    // Send completion message and finish the stream
    let completionMessage = "✅ Successfully sent \(event.count) messages\n"
    try await responseWriter.writeAndFinish(ByteBuffer(string: completionMessage))

    // Optional: Do background work here after response is sent
    context.logger.info("Background work: cleaning up resources and logging metrics")

    // Simulate some background processing
    try await Task.sleep(for: .milliseconds(100))
    context.logger.info("Background work completed")
}

try await runtime.run()
