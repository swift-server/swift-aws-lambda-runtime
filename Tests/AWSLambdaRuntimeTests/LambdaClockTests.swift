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

@Suite("LambdaClock Tests")
struct LambdaClockTests {

    @Test("Clock provides current time")
    func clockProvidesCurrentTime() {
        let clock = LambdaClock()
        let now = clock.now

        // Verify we get a reasonable timestamp (after today)
        let dateOfWritingThisTestInMillis: Int64 = 1_754_130_134_000
        #expect(now.instant > dateOfWritingThisTestInMillis)
    }

    @Test("Instant can be advanced by duration")
    func instantCanBeAdvancedByDuration() {
        let clock = LambdaClock()
        let start = clock.now
        let advanced = start.advanced(by: .seconds(30))

        #expect(advanced.instant == start.instant + 30_000)
    }

    @Test("Duration calculation between instants")
    func durationCalculationBetweenInstants() {
        let clock = LambdaClock()
        let start = clock.now
        let end = start.advanced(by: .seconds(5))

        let duration = start.duration(to: end)
        #expect(duration == .seconds(5))
    }

    @Test("Instant comparison works correctly")
    func instantComparisonWorksCorrectly() {
        let clock = LambdaClock()
        let earlier = clock.now
        let later = earlier.advanced(by: .milliseconds(1))

        #expect(earlier < later)
        #expect(!(later < earlier))
    }

    @Test("Clock minimum resolution is milliseconds")
    func clockMinimumResolutionIsMilliseconds() {
        let clock = LambdaClock()
        #expect(clock.minimumResolution == .milliseconds(1))
    }

    @Test("Sleep until deadline works")
    func sleepUntilDeadlineWorks() async throws {
        let clock = LambdaClock()
        let start = clock.now
        let deadline = start.advanced(by: .milliseconds(50))

        try await clock.sleep(until: deadline, tolerance: nil)

        let end = clock.now
        let elapsed = start.duration(to: end)

        // Allow some tolerance for timing precision
        #expect(elapsed >= .milliseconds(40))
        #expect(elapsed <= .milliseconds(100))
    }

    @Test("Sleep with past deadline returns immediately")
    func sleepWithPastDeadlineReturnsImmediately() async throws {
        let clock = LambdaClock()
        let now = clock.now
        let pastDeadline = now.advanced(by: .milliseconds(-100))

        let start = clock.now
        try await clock.sleep(until: pastDeadline, tolerance: nil)
        let end = clock.now

        let elapsed = start.duration(to: end)
        // Should return almost immediately
        #expect(elapsed < .milliseconds(10))
    }

    @Test("Duration to future instant returns negative duration")
    func durationToFutureInstantReturnsNegativeDuration() {
        let clock = LambdaClock()
        let futureDeadline = clock.now.advanced(by: .seconds(30))
        let currentTime = clock.now

        // This simulates getRemainingTime() where deadline is in future
        let remainingTime = futureDeadline.duration(to: currentTime)

        // Should be negative since we're going from future to present
        #expect(remainingTime < .zero)
        #expect(remainingTime <= .seconds(-29))  // Allow some timing tolerance
    }
}
