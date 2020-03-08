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

func runLambda(behavior: LambdaServerBehavior, handler: LambdaHandler) throws {
    try runLambda(behavior: behavior, provider: { _ in handler })
}

func runLambda(behavior: LambdaServerBehavior, provider: @escaping (EventLoop) throws -> LambdaHandler) throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
    let logger = Logger(label: "TestLogger")
    let configuration = Lambda.Configuration(runtimeEngine: .init(requestTimeout: .milliseconds(100)))
    let runner = Lambda.Runner(eventLoop: eventLoopGroup.next(), configuration: configuration, provider: provider)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    defer { XCTAssertNoThrow(try server.stop().wait()) }
    try runner.initialize(logger: logger).flatMap { handler in
        runner.run(logger: logger, handler: handler)
    }.wait()
}

final class EchoHandler: LambdaHandler, BootstrappedLambdaHandler {
    var bootstrapped = 0

    func bootstrap(eventLoop: EventLoop, promise: EventLoopPromise<Void>) {
        self.bootstrapped += 1
        promise.succeed(())
    }

    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        promise.succeed(payload)
    }
}

struct FailedHandler: LambdaHandler {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        promise.fail(TestError(self.reason))
    }
}

struct FailedBootstrapHandler: LambdaHandler, BootstrappedLambdaHandler {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func bootstrap(eventLoop: EventLoop, promise: EventLoopPromise<Void>) {
        promise.fail(TestError(self.reason))
    }

    func handle(context: Lambda.Context, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer?>) {
        promise.fail(TestError("should not be called"))
    }
}

struct TestError: Swift.Error, Equatable, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
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
