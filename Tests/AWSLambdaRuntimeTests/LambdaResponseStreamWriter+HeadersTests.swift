//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime
import Logging
import NIOCore
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("LambdaResponseStreamWriter+Headers Tests")
struct LambdaResponseStreamWriterHeadersTests {

    @Test("Write status and headers with minimal response (status code only)")
    func testWriteStatusAndHeadersMinimal() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        try await writer.writeStatusAndHeaders(response)

        // Verify we have exactly 2 buffers written (JSON + separator)
        #expect(writer.writtenBuffers.count == 2)

        // Verify JSON content
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)
        let expectedJSON = #"{"statusCode":200}"#
        #expect(jsonString == expectedJSON)

        // Verify separator (8 null bytes)
        let separatorBuffer = writer.writtenBuffers[1]
        let separatorBytes = separatorBuffer.getBytes(at: 0, length: separatorBuffer.readableBytes)
        let expectedSeparator: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(separatorBytes == expectedSeparator)
    }

    @Test("Write status and headers with full response (all fields populated)")
    func testWriteStatusAndHeadersFull() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 201,
            headers: [
                "Content-Type": "application/json",
                "Cache-Control": "no-cache",
            ],
            multiValueHeaders: [
                "Set-Cookie": ["session=abc123", "theme=dark"],
                "X-Custom": ["value1", "value2"],
            ]
        )

        try await writer.writeStatusAndHeaders(response)

        // Verify we have exactly 2 buffers written (JSON + separator)
        #expect(writer.writtenBuffers.count == 2)

        // Verify JSON content structure
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)

        // Parse JSON to verify structure
        let jsonData = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        let parsedResponse = try decoder.decode(StreamingLambdaStatusAndHeadersResponse.self, from: jsonData)

        #expect(parsedResponse.statusCode == 201)

        #expect(parsedResponse.headers?["Content-Type"] == "application/json")
        #expect(parsedResponse.headers?["Cache-Control"] == "no-cache")

        #expect(parsedResponse.multiValueHeaders?["Set-Cookie"] == ["session=abc123", "theme=dark"])
        #expect(parsedResponse.multiValueHeaders?["X-Custom"] == ["value1", "value2"])

        // Verify separator (8 null bytes)
        let separatorBuffer = writer.writtenBuffers[1]
        let separatorBytes = separatorBuffer.getBytes(at: 0, length: separatorBuffer.readableBytes)
        let expectedSeparator: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(separatorBytes == expectedSeparator)
    }

    @Test("Write status and headers with custom encoder")
    func testWriteStatusAndHeadersWithCustomEncoder() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 404,
            headers: ["Error": "Not Found"]
        )

        // Use custom encoder with different formatting
        let customEncoder = JSONEncoder()
        customEncoder.outputFormatting = .sortedKeys

        try await writer.writeStatusAndHeaders(response, encoder: customEncoder)

        // Verify we have exactly 2 buffers written (JSON + separator)
        #expect(writer.writtenBuffers.count == 2)

        // Verify JSON content with sorted keys
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)

        // With sorted keys, "headers" should come before "statusCode"
        #expect(jsonString.contains(#""headers":{"Error":"Not Found"}"#))
        #expect(jsonString.contains(#""statusCode":404"#))

        // Verify separator
        let separatorBuffer = writer.writtenBuffers[1]
        #expect(separatorBuffer.readableBytes == 8)
    }

    @Test("Write status and headers with only headers (no multiValueHeaders)")
    func testWriteStatusAndHeadersOnlyHeaders() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 302,
            headers: ["Location": "https://example.com"]
        )

        try await writer.writeStatusAndHeaders(response)

        // Verify JSON structure
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)
        let jsonData = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        let parsedResponse = try decoder.decode(StreamingLambdaStatusAndHeadersResponse.self, from: jsonData)

        #expect(parsedResponse.statusCode == 302)

        #expect(parsedResponse.headers?["Location"] == "https://example.com")

        // multiValueHeaders should be null/nil in JSON
        #expect(parsedResponse.multiValueHeaders == nil)
    }

    @Test("Write status and headers with only multiValueHeaders (no headers)")
    func testWriteStatusAndHeadersOnlyMultiValueHeaders() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 200,
            multiValueHeaders: [
                "Accept": ["application/json", "text/html"]
            ]
        )

        try await writer.writeStatusAndHeaders(response)

        // Verify JSON structure
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)
        let jsonData = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        let parsedResponse = try decoder.decode(StreamingLambdaStatusAndHeadersResponse.self, from: jsonData)

        #expect(parsedResponse.statusCode == 200)

        // headers should be null/nil in JSON
        #expect(parsedResponse.headers == nil)

        #expect(parsedResponse.multiValueHeaders?["Accept"] == ["application/json", "text/html"])
    }

    @Test("Verify JSON serialization format matches expected structure")
    func testJSONSerializationFormat() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 418,
            headers: ["X-Tea": "Earl Grey"],
            multiValueHeaders: ["X-Brew": ["hot", "strong"]]
        )

        try await writer.writeStatusAndHeaders(response)

        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)

        // Verify it's valid JSON by decoding
        let jsonData = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        #expect(throws: Never.self) {
            _ = try decoder.decode(StreamingLambdaStatusAndHeadersResponse.self, from: jsonData)
        }

        // Verify specific structure
        let parsedResponse = try decoder.decode(StreamingLambdaStatusAndHeadersResponse.self, from: jsonData)

        // Must have statusCode
        #expect(parsedResponse.statusCode == 418)

        // Must have headers when provided
        #expect(parsedResponse.headers?["X-Tea"] == "Earl Grey")

        // Must have multiValueHeaders when provided
        #expect(parsedResponse.multiValueHeaders?["X-Brew"] == ["hot", "strong"])
    }

    @Test("Verify null byte separator is exactly 8 bytes")
    func testNullByteSeparatorLength() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        try await writer.writeStatusAndHeaders(response)

        #expect(writer.writtenBuffers.count == 2)

        let separatorBuffer = writer.writtenBuffers[1]
        #expect(separatorBuffer.readableBytes == 8)

        // Verify all bytes are 0x00
        let separatorBytes = separatorBuffer.getBytes(at: 0, length: 8)!
        for byte in separatorBytes {
            #expect(byte == 0x00)
        }
    }

    // MARK: - Error Handling Tests

    @Test("JSON serialization error propagation")
    func testJSONSerializationErrorPropagation() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        // Create a failing encoder that always throws an error
        let failingEncoder = FailingEncoder()

        // Verify that the encoder error is propagated
        await #expect(throws: TestEncodingError.self) {
            try await writer.writeStatusAndHeaders(response, encoder: failingEncoder)
        }

        // Verify no data was written when encoding fails
        #expect(writer.writtenBuffers.isEmpty)
    }

    @Test("Write method error propagation for JSON data")
    func testWriteMethodErrorPropagationForJSON() async throws {
        let writer = FailingMockLambdaResponseStreamWriter(failOnWriteCall: 1)  // Fail on first write (JSON)
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        // Verify that the write error is propagated
        await #expect(throws: TestWriteError.self) {
            try await writer.writeStatusAndHeaders(response)
        }

        // Verify the writer attempted to write once (the JSON data)
        #expect(writer.writeCallCount == 1)
    }

    @Test("Write method error propagation for separator")
    func testWriteMethodErrorPropagationForSeparator() async throws {
        let writer = FailingMockLambdaResponseStreamWriter(failOnWriteCall: 2)  // Fail on second write (separator)
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        // Verify that the write error is propagated
        await #expect(throws: TestWriteError.self) {
            try await writer.writeStatusAndHeaders(response)
        }

        // Verify the writer attempted to write twice (JSON succeeded, separator failed)
        #expect(writer.writeCallCount == 2)
        // Verify JSON was written successfully before separator failure
        #expect(writer.writtenBuffers.count == 1)
    }

    @Test("Error types and messages are properly handled")
    func testErrorTypesAndMessages() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        // Test with a custom encoder that throws a specific error
        let customFailingEncoder = CustomFailingEncoder()

        do {
            try await writer.writeStatusAndHeaders(response, encoder: customFailingEncoder)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as CustomEncodingError {
            // Verify the specific error type and message are preserved
            #expect(error.message == "Custom encoding failed")
            #expect(error.code == 42)
        } catch {
            #expect(Bool(false), "Expected CustomEncodingError but got \(type(of: error))")
        }
    }

    @Test("JSONEncoder error propagation with invalid data")
    func testJSONEncoderErrorPropagation() async throws {
        let writer = MockLambdaResponseStreamWriter()

        // Create a response that should encode successfully
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        // Note: It's difficult to make JSONEncoder fail with valid Codable types,
        // so we'll use our custom failing encoder to simulate this scenario
        let failingJSONEncoder = FailingJSONEncoder()

        await #expect(throws: TestJSONEncodingError.self) {
            try await writer.writeStatusAndHeaders(response, encoder: failingJSONEncoder)
        }

        // Verify no data was written when encoding fails
        #expect(writer.writtenBuffers.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Integration: writeStatusAndHeaders with existing streaming methods")
    func testIntegrationWithExistingStreamingMethods() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain"]
        )

        // Write headers first
        try await writer.writeStatusAndHeaders(response)

        // Then use existing streaming methods
        let bodyData = "Hello, World!"
        var bodyBuffer = ByteBuffer()
        bodyBuffer.writeString(bodyData)

        try await writer.write(bodyBuffer)

        let moreData = " Additional content."
        var moreBuffer = ByteBuffer()
        moreBuffer.writeString(moreData)

        try await writer.writeAndFinish(moreBuffer)

        // Verify the sequence: JSON + separator + body + more body
        #expect(writer.writtenBuffers.count == 4)
        #expect(writer.isFinished == true)

        // Verify JSON content
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)
        #expect(jsonString.contains(#""statusCode":200"#))
        #expect(jsonString.contains(#""Content-Type":"text\/plain""#))

        // Verify separator
        let separatorBuffer = writer.writtenBuffers[1]
        #expect(separatorBuffer.readableBytes == 8)

        // Verify body content
        let firstBodyBuffer = writer.writtenBuffers[2]
        let firstBodyString = String(buffer: firstBodyBuffer)
        #expect(firstBodyString == "Hello, World!")

        let secondBodyBuffer = writer.writtenBuffers[3]
        let secondBodyString = String(buffer: secondBodyBuffer)
        #expect(secondBodyString == " Additional content.")
    }

    @Test("Integration: multiple header writes work correctly")
    func testMultipleHeaderWrites() async throws {
        let writer = MockLambdaResponseStreamWriter()

        // First header write
        let firstResponse = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"]
        )
        try await writer.writeStatusAndHeaders(firstResponse)

        // Second header write (should work - multiple headers are allowed)
        let secondResponse = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 201,
            headers: ["Location": "https://example.com/resource/123"]
        )
        try await writer.writeStatusAndHeaders(secondResponse)

        // Verify both header writes were successful
        #expect(writer.writtenBuffers.count == 4)  // 2 JSON + 2 separators

        // Verify first header write
        let firstJsonBuffer = writer.writtenBuffers[0]
        let firstJsonString = String(buffer: firstJsonBuffer)
        #expect(firstJsonString.contains(#""statusCode":200"#))
        #expect(firstJsonString.contains(#""Content-Type":"application\/json""#))

        // Verify first separator
        let firstSeparatorBuffer = writer.writtenBuffers[1]
        #expect(firstSeparatorBuffer.readableBytes == 8)

        // Verify second header write
        let secondJsonBuffer = writer.writtenBuffers[2]
        let secondJsonString = String(buffer: secondJsonBuffer)
        #expect(secondJsonString.contains(#""statusCode":201"#))
        #expect(secondJsonString.contains(#""Location":"https:\/\/example.com\/resource\/123""#))

        // Verify second separator
        let secondSeparatorBuffer = writer.writtenBuffers[3]
        #expect(secondSeparatorBuffer.readableBytes == 8)
    }

    @Test("Integration: header write followed by body streaming compatibility")
    func testHeaderWriteFollowedByBodyStreaming() async throws {
        let writer = MockLambdaResponseStreamWriter()

        // Write headers first
        let response = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            multiValueHeaders: ["Set-Cookie": ["session=abc123", "theme=dark"]]
        )
        try await writer.writeStatusAndHeaders(response)

        // Stream body content in multiple chunks
        let chunks = [
            #"{"users": ["#,
            #"{"id": 1, "name": "Alice"}, "#,
            #"{"id": 2, "name": "Bob"}"#,
            #"]}"#,
        ]

        for (index, chunk) in chunks.enumerated() {
            var buffer = ByteBuffer()
            buffer.writeString(chunk)

            if index == chunks.count - 1 {
                // Use writeAndFinish for the last chunk
                try await writer.writeAndFinish(buffer)
            } else {
                try await writer.write(buffer)
            }
        }

        // Verify the complete sequence
        #expect(writer.writtenBuffers.count == 6)  // JSON + separator + 4 body chunks
        #expect(writer.isFinished == true)

        // Verify headers were written correctly
        let jsonBuffer = writer.writtenBuffers[0]
        let jsonString = String(buffer: jsonBuffer)
        #expect(jsonString.contains(#""statusCode":200"#))
        #expect(jsonString.contains(#""Content-Type":"application\/json""#))
        #expect(jsonString.contains(#""Set-Cookie":["session=abc123","theme=dark"]"#))

        // Verify separator
        let separatorBuffer = writer.writtenBuffers[1]
        #expect(separatorBuffer.readableBytes == 8)

        // Verify body chunks
        let bodyChunks = writer.writtenBuffers[2...5].map { String(buffer: $0) }
        let completeBody = bodyChunks.joined()
        let expectedBody = #"{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]}"#
        #expect(completeBody == expectedBody)
    }

    @Test("Integration: verify method works with different LambdaResponseStreamWriter implementations")
    func testWithDifferentWriterImplementations() async throws {
        // Test with basic mock implementation
        let basicWriter = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        try await basicWriter.writeStatusAndHeaders(response)
        #expect(basicWriter.writtenBuffers.count == 2)

        // Test with a writer that tracks additional state
        let trackingWriter = TrackingLambdaResponseStreamWriter()
        try await trackingWriter.writeStatusAndHeaders(response)
        #expect(trackingWriter.writtenBuffers.count == 2)
        #expect(trackingWriter.writeCallCount == 2)  // JSON + separator
        #expect(trackingWriter.finishCallCount == 0)

        // Test with a writer that has custom behavior
        let customWriter = CustomBehaviorLambdaResponseStreamWriter()
        try await customWriter.writeStatusAndHeaders(response)
        #expect(customWriter.writtenBuffers.count == 2)
        #expect(customWriter.customBehaviorTriggered == true)
    }

    @Test("Integration: complex scenario with headers, streaming, and finish")
    func testComplexIntegrationScenario() async throws {
        let writer = MockLambdaResponseStreamWriter()

        // Step 1: Write initial headers
        let initialResponse = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/event-stream", "Cache-Control": "no-cache"]
        )
        try await writer.writeStatusAndHeaders(initialResponse)

        // Step 2: Write additional headers (simulating server-sent events setup)
        let sseResponse = StreamingLambdaStatusAndHeadersResponse(
            statusCode: 200,
            headers: ["Connection": "keep-alive"]
        )
        try await writer.writeStatusAndHeaders(sseResponse)

        // Step 3: Stream event data
        let events = [
            "data: Event 1\n\n",
            "data: Event 2\n\n",
            "data: Event 3\n\n",
        ]

        for event in events {
            var buffer = ByteBuffer()
            buffer.writeString(event)
            try await writer.write(buffer)
        }

        // Step 4: Send final event and finish
        var finalBuffer = ByteBuffer()
        finalBuffer.writeString("data: Final event\n\n")
        try await writer.writeAndFinish(finalBuffer)

        // Verify the complete sequence
        // 2 header writes (JSON + separator each) + 3 events + 1 final event = 8 buffers
        #expect(writer.writtenBuffers.count == 8)
        #expect(writer.isFinished == true)

        // Verify headers
        let firstJsonString = String(buffer: writer.writtenBuffers[0])
        #expect(firstJsonString.contains(#""Content-Type":"text\/event-stream""#))

        let secondJsonString = String(buffer: writer.writtenBuffers[2])
        #expect(secondJsonString.contains(#""Connection":"keep-alive""#))

        // Verify events
        let eventBuffers = [
            writer.writtenBuffers[4], writer.writtenBuffers[5], writer.writtenBuffers[6], writer.writtenBuffers[7],
        ]
        let eventStrings = eventBuffers.map { String(buffer: $0) }
        #expect(eventStrings[0] == "data: Event 1\n\n")
        #expect(eventStrings[1] == "data: Event 2\n\n")
        #expect(eventStrings[2] == "data: Event 3\n\n")
        #expect(eventStrings[3] == "data: Final event\n\n")
    }

    @Test("Integration: verify compatibility with protocol requirements")
    func testProtocolCompatibility() async throws {
        let writer = MockLambdaResponseStreamWriter()
        let response = StreamingLambdaStatusAndHeadersResponse(statusCode: 200)

        // Verify the method can be called on any LambdaResponseStreamWriter
        func testWithGenericWriter<W: LambdaResponseStreamWriter>(_ writer: W) async throws {
            try await writer.writeStatusAndHeaders(response)
        }

        // This should compile and work without issues
        try await testWithGenericWriter(writer)
        #expect(writer.writtenBuffers.count == 2)

        // Verify it works with protocol existential
        let protocolWriter: any LambdaResponseStreamWriter = MockLambdaResponseStreamWriter()
        try await protocolWriter.writeStatusAndHeaders(response)

        if let mockWriter = protocolWriter as? MockLambdaResponseStreamWriter {
            #expect(mockWriter.writtenBuffers.count == 2)
        }
    }
}

// MARK: - Mock Implementation

/// Mock implementation of LambdaResponseStreamWriter for testing
final class MockLambdaResponseStreamWriter: LambdaResponseStreamWriter {
    private(set) var writtenBuffers: [ByteBuffer] = []
    private(set) var isFinished = false

    func write(_ buffer: ByteBuffer) async throws {
        writtenBuffers.append(buffer)
    }

    func finish() async throws {
        isFinished = true
    }

    func writeAndFinish(_ buffer: ByteBuffer) async throws {
        writtenBuffers.append(buffer)
        isFinished = true
    }
}

// MARK: - Error Handling Mock Implementations

/// Mock implementation that fails on specific write calls for testing error propagation
final class FailingMockLambdaResponseStreamWriter: LambdaResponseStreamWriter {
    private(set) var writtenBuffers: [ByteBuffer] = []
    private(set) var writeCallCount = 0
    private(set) var isFinished = false
    private let failOnWriteCall: Int

    init(failOnWriteCall: Int) {
        self.failOnWriteCall = failOnWriteCall
    }

    func write(_ buffer: ByteBuffer) async throws {
        writeCallCount += 1

        if writeCallCount == failOnWriteCall {
            throw TestWriteError()
        }

        writtenBuffers.append(buffer)
    }

    func finish() async throws {
        isFinished = true
    }

    func writeAndFinish(_ buffer: ByteBuffer) async throws {
        try await write(buffer)
        try await finish()
    }
}

// MARK: - Test Error Types

/// Test error for write method failures
struct TestWriteError: Error, Equatable {
    let message: String

    init(message: String = "Test write error") {
        self.message = message
    }
}

/// Test error for encoding failures
struct TestEncodingError: Error, Equatable {
    let message: String

    init(message: String = "Test encoding error") {
        self.message = message
    }
}

/// Custom test error with additional properties
struct CustomEncodingError: Error, Equatable {
    let message: String
    let code: Int

    init(message: String = "Custom encoding failed", code: Int = 42) {
        self.message = message
        self.code = code
    }
}

/// Test error for JSON encoding failures
struct TestJSONEncodingError: Error, Equatable {
    let message: String

    init(message: String = "Test JSON encoding error") {
        self.message = message
    }
}

// MARK: - Failing Encoder Implementations

/// Mock encoder that always fails for testing error propagation
struct FailingEncoder: LambdaOutputEncoder {
    typealias Output = StreamingLambdaStatusAndHeadersResponse

    func encode(_ value: StreamingLambdaStatusAndHeadersResponse, into buffer: inout ByteBuffer) throws {
        throw TestEncodingError()
    }
}

/// Mock encoder that throws custom errors for testing specific error handling
struct CustomFailingEncoder: LambdaOutputEncoder {
    typealias Output = StreamingLambdaStatusAndHeadersResponse

    func encode(_ value: StreamingLambdaStatusAndHeadersResponse, into buffer: inout ByteBuffer) throws {
        throw CustomEncodingError()
    }
}

/// Mock JSON encoder that always fails for testing JSON-specific error propagation
struct FailingJSONEncoder: LambdaOutputEncoder {
    typealias Output = StreamingLambdaStatusAndHeadersResponse

    func encode(_ value: StreamingLambdaStatusAndHeadersResponse, into buffer: inout ByteBuffer) throws {
        throw TestJSONEncodingError()
    }
}

// MARK: - Additional Mock Implementations for Integration Tests

/// Mock implementation that tracks additional state for integration testing
final class TrackingLambdaResponseStreamWriter: LambdaResponseStreamWriter {
    private(set) var writtenBuffers: [ByteBuffer] = []
    private(set) var writeCallCount = 0
    private(set) var finishCallCount = 0
    private(set) var writeAndFinishCallCount = 0
    private(set) var isFinished = false

    func write(_ buffer: ByteBuffer) async throws {
        writeCallCount += 1
        writtenBuffers.append(buffer)
    }

    func finish() async throws {
        finishCallCount += 1
        isFinished = true
    }

    func writeAndFinish(_ buffer: ByteBuffer) async throws {
        writeAndFinishCallCount += 1
        writtenBuffers.append(buffer)
        isFinished = true
    }
}

/// Mock implementation with custom behavior for integration testing
final class CustomBehaviorLambdaResponseStreamWriter: LambdaResponseStreamWriter {
    private(set) var writtenBuffers: [ByteBuffer] = []
    private(set) var customBehaviorTriggered = false
    private(set) var isFinished = false

    func write(_ buffer: ByteBuffer) async throws {
        // Trigger custom behavior on any write
        customBehaviorTriggered = true
        writtenBuffers.append(buffer)
    }

    func finish() async throws {
        isFinished = true
    }

    func writeAndFinish(_ buffer: ByteBuffer) async throws {
        customBehaviorTriggered = true
        writtenBuffers.append(buffer)
        isFinished = true
    }
}
