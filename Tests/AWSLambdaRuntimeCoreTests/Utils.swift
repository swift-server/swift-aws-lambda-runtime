//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaRuntimeCore
import Logging
import NIOCore
import NIOPosix
import XCTest

func runLambda<Handler: ByteBufferLambdaHandler>(behavior: LambdaServerBehavior, handlerType: Handler.Type) throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
    let logger = Logger(label: "TestLogger")
    let configuration = LambdaConfiguration(runtimeEngine: .init(requestTimeout: .milliseconds(100)))
    let terminator = LambdaTerminator()
    let runner = LambdaRunner(eventLoop: eventLoopGroup.next(), configuration: configuration)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    defer { XCTAssertNoThrow(try server.stop().wait()) }
    try runner.initialize(logger: logger, terminator: terminator, handlerType: handlerType).flatMap { handler in
        runner.run(logger: logger, handler: handler)
    }.wait()
}

func assertLambdaRuntimeResult(_ result: @autoclosure () throws -> Int, shouldHaveRun: Int = 0, shouldFailWithError: Error? = nil, file: StaticString = #file, line: UInt = #line) {
    do {
        let count = try result()
        if let shouldFailWithError = shouldFailWithError {
            XCTFail("should fail with \(shouldFailWithError)", file: file, line: line)
        } else {
            XCTAssertEqual(shouldHaveRun, count, "should have run \(shouldHaveRun) times", file: file, line: line)
        }
    } catch {
        if let shouldFailWithError = shouldFailWithError {
            XCTAssertEqual(String(describing: shouldFailWithError), String(describing: error), "expected error to match", file: file, line: line)
        } else {
            XCTFail("should succeed, but failed with \(error)", file: file, line: line)
        }
    }
}

struct TestError: Error, Equatable, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

extension Date {
    internal var millisSinceEpoch: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}

extension LambdaRuntimeError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        // technically incorrect, but good enough for our tests
        String(describing: lhs) == String(describing: rhs)
    }
}

extension LambdaTerminator.TerminationError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.underlying.count == rhs.underlying.count else {
            return false
        }
        // technically incorrect, but good enough for our tests
        return String(describing: lhs) == String(describing: rhs)
    }
}
