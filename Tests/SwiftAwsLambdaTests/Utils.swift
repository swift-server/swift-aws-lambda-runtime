//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
@testable import SwiftAwsLambda
import XCTest

func runLambda(behavior: LambdaServerBehavior, handler: ByteBufferLambdaHandler) throws {
    try runLambda(behavior: behavior, factory: { $0.makeSucceededFuture(handler) })
}

func runLambda(behavior: LambdaServerBehavior, factory: @escaping LambdaHandlerFactory) throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
    let logger = Logger(label: "TestLogger")
    let configuration = Lambda.Configuration(runtimeEngine: .init(requestTimeout: .milliseconds(100)))
    let runner = Lambda.Runner(eventLoop: eventLoopGroup.next(), configuration: configuration)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    defer { XCTAssertNoThrow(try server.stop().wait()) }
    try runner.initialize(logger: logger, factory: factory).flatMap { handler in
        runner.run(logger: logger, handler: handler)
    }.wait()
}

struct EchoHandler: LambdaHandler {
    typealias In = String
    typealias Out = String

    func handle(context: Lambda.Context, payload: String, callback: (Result<String, Error>) -> Void) {
        callback(.success(payload))
    }
}

struct FailedHandler: LambdaHandler {
    typealias In = String
    typealias Out = Void

    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context: Lambda.Context, payload: String, callback: (Result<Void, Error>) -> Void) {
        callback(.failure(TestError(self.reason)))
    }
}

func assertLambdaLifecycleResult(_ result: Result<Int, Error>, shoudHaveRun: Int = 0, shouldFailWithError: Error? = nil, file: StaticString = #file, line: UInt = #line) {
    switch result {
    case .success where shouldFailWithError != nil:
        XCTFail("should fail with \(shouldFailWithError!)", file: file, line: line)
    case .success(let count) where shouldFailWithError == nil:
        XCTAssertEqual(shoudHaveRun, count, "should have run \(shoudHaveRun) times", file: file, line: line)
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

internal extension Date {
    var millisSinceEpoch: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}

extension Lambda.RuntimeError: Equatable {
    public static func == (lhs: Lambda.RuntimeError, rhs: Lambda.RuntimeError) -> Bool {
        // technically incorrect, but good enough for our tests
        String(describing: lhs) == String(describing: rhs)
    }
}
