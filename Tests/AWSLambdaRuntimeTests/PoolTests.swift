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

import Testing

@testable import AWSLambdaRuntime

struct PoolTests {

    @Test
    @available(LambdaSwift 2.0, *)
    func testBasicPushAndIteration() async throws {
        let pool = LambdaHTTPServer.Pool<String>()

        // Push values
        pool.push("first")
        pool.push("second")

        // Iterate and verify order
        var values = [String]()
        for try await value in pool {
            values.append(value)
            if values.count == 2 { break }
        }

        #expect(values == ["first", "second"])
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testPoolCancellation() async throws {
        let pool = LambdaHTTPServer.Pool<String>()

        // Create a task that will be cancelled
        let task = Task {
            for try await _ in pool {
                Issue.record("Should not receive any values after cancellation")
            }
        }

        // Cancel the task immediately
        task.cancel()

        // This should complete without receiving any values
        do {
            try await task.value
        } catch is CancellationError {}  // this might happen depending on the order on which the cancellation is handled
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testConcurrentPushAndIteration() async throws {
        let pool = LambdaHTTPServer.Pool<Int>()
        let iterations = 1000

        // Start consumer task first
        let consumer = Task { @Sendable in
            var receivedValues = Set<Int>()
            var count = 0
            for try await value in pool {
                receivedValues.insert(value)
                count += 1
                if count >= iterations { break }
            }
            return receivedValues
        }

        // Create multiple producer tasks
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    pool.push(i)
                }
            }
            try await group.waitForAll()
        }

        // Wait for consumer to complete
        let receivedValues = try await consumer.value

        // Verify all values were received exactly once
        #expect(receivedValues.count == iterations)
        #expect(Set(0..<iterations) == receivedValues)
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testPushToWaitingConsumer() async throws {
        let pool = LambdaHTTPServer.Pool<String>()
        let expectedValue = "test value"

        // Start a consumer that will wait for a value
        let consumer = Task {
            for try await value in pool {
                #expect(value == expectedValue)
                break
            }
        }

        // Give consumer time to start waiting
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Push a value
        pool.push(expectedValue)

        // Wait for consumer to complete
        try await consumer.value
    }

    @Test
    @available(LambdaSwift 2.0, *)
    func testStressTest() async throws {
        let pool = LambdaHTTPServer.Pool<Int>()
        let producerCount = 10
        let messagesPerProducer = 1000

        // Start consumer
        let consumer = Task { @Sendable in
            var receivedValues = [Int]()
            var count = 0
            for try await value in pool {
                receivedValues.append(value)
                count += 1
                if count >= producerCount * messagesPerProducer { break }
            }
            return receivedValues
        }

        // Create multiple producers
        try await withThrowingTaskGroup(of: Void.self) { group in
            for p in 0..<producerCount {
                group.addTask {
                    for i in 0..<messagesPerProducer {
                        pool.push(p * messagesPerProducer + i)
                    }
                }
            }
            try await group.waitForAll()
        }

        // Wait for consumer to complete
        let receivedValues = try await consumer.value

        // Verify we received all values
        #expect(receivedValues.count == producerCount * messagesPerProducer)
        #expect(Set(receivedValues).count == producerCount * messagesPerProducer)
    }
}
