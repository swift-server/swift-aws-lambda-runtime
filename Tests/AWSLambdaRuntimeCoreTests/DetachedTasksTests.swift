//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import XCTest

@testable import AWSLambdaRuntimeCore

class DetachedTasksTest: XCTestCase {
    actor Expectation {
        var isFulfilled = false
        func fulfill() {
            self.isFulfilled = true
        }
    }

    func testAwaitTasks() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let context = DetachedTasksContainer.Context(
            eventLoop: eventLoopGroup.next(),
            logger: Logger(label: "test")
        )
        let expectation = Expectation()

        let container = DetachedTasksContainer(context: context)
        await container.detached {
            try! await Task.sleep(for: .milliseconds(200))
            await expectation.fulfill()
        }

        try await container.awaitAll().get()
        let isFulfilled = await expectation.isFulfilled
        XCTAssert(isFulfilled)
    }

    func testAwaitChildrenTasks() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

        let context = DetachedTasksContainer.Context(
            eventLoop: eventLoopGroup.next(),
            logger: Logger(label: "test")
        )
        let expectation1 = Expectation()
        let expectation2 = Expectation()

        let container = DetachedTasksContainer(context: context)
        await container.detached {
            await container.detached {
                try! await Task.sleep(for: .milliseconds(300))
                await expectation1.fulfill()
            }
            try! await Task.sleep(for: .milliseconds(200))
            await container.detached {
                try! await Task.sleep(for: .milliseconds(100))
                await expectation2.fulfill()
            }
        }

        try await container.awaitAll().get()
        let isFulfilled1 = await expectation1.isFulfilled
        let isFulfilled2 = await expectation2.isFulfilled
        XCTAssert(isFulfilled1)
        XCTAssert(isFulfilled2)
    }
}
