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

func runLambda<Handler: SimpleLambdaHandler>(behavior: LambdaServerBehavior, handlerType: Handler.Type) throws {
    try runLambda(behavior: behavior, handlerProvider: Handler.makeCodableHandler)
}

func runLambda<Handler: LambdaHandler>(behavior: LambdaServerBehavior, handlerType: Handler.Type) throws {
    try runLambda(behavior: behavior, handlerProvider: Handler.makeCodableHandler)
}

func runLambda<Handler: EventLoopLambdaHandler>(behavior: LambdaServerBehavior, handlerType: Handler.Type) throws {
    try runLambda(behavior: behavior, handlerProvider: CodableEventLoopLambdaHandler<Handler>.makeHandler)
}

func runLambda(behavior: LambdaServerBehavior,
               handlerProvider: (LambdaInitializationContext) -> EventLoopFuture<some NonFactoryByteBufferLambdaHandler>) throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
    let logger = Logger(label: "TestLogger")
    let configuration = LambdaConfiguration(runtimeEngine: .init(requestTimeout: .milliseconds(100)))
    let terminator = LambdaTerminator()
    let runner = LambdaRunner(eventLoop: eventLoopGroup.next(), configuration: configuration)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    defer { XCTAssertNoThrow(try server.stop().wait()) }
    try runner.initialize(handlerProvider: handlerProvider, logger: logger, terminator: terminator).flatMap { handler in
        runner.run(handler: handler, logger: logger)
    }.wait()
}

func assertLambdaRuntimeResult(_ result: Result<Int, Error>, shouldHaveRun: Int = 0, shouldFailWithError: Error? = nil, file: StaticString = #file, line: UInt = #line) {
    switch result {
    case .success where shouldFailWithError != nil:
        XCTFail("should fail with \(shouldFailWithError!)", file: file, line: line)
    case .success(let count) where shouldFailWithError == nil:
        XCTAssertEqual(shouldHaveRun, count, "should have run \(shouldHaveRun) times", file: file, line: line)
    case .failure(let error) where shouldFailWithError == nil:
        XCTFail("should succeed, but failed with \(error)", file: file, line: line)
    case .failure(let error) where shouldFailWithError != nil:
        XCTAssertEqual(String(describing: shouldFailWithError!), String(describing: error), "expected error to mactch", file: file, line: line)
    default:
        XCTFail("invalid state")
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
