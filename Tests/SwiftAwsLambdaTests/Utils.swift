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
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
    let logger = Logger(label: "TestLogger")
    let configuration = Lambda.Configuration(runtimeEngine: .init(requestTimeout: .milliseconds(100)))
    let runner = LambdaRunner(eventLoop: eventLoopGroup.next(), configuration: configuration, lambdaHandler: handler)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    defer { XCTAssertNoThrow(try server.stop().wait()) }
    try runner.initialize(logger: logger).flatMap {
        runner.run(logger: logger)
    }.wait()
}

final class EchoHandler: LambdaHandler, InitializableLambdaHandler {
    var initializeCalls = 0

    func initialize(promise: EventLoopPromise<Void>) {
        self.initializeCalls += 1
        promise.succeed(())
    }

    func handle(context: LambdaContext, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer>) {
        promise.succeed(payload)
    }
}

struct FailedHandler: LambdaHandler {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context: LambdaContext, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer>) {
        promise.fail(Error(description: self.reason))
    }

    struct Error: Swift.Error, Equatable, CustomStringConvertible {
        let description: String
    }
}

struct FailedInitializerHandler: LambdaHandler, InitializableLambdaHandler {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context: LambdaContext, payload: ByteBuffer, promise: EventLoopPromise<ByteBuffer>) {
        promise.succeed(payload)
    }

    func initialize(promise: EventLoopPromise<Void>) {
        promise.fail(Error(description: self.reason))
    }

    public struct Error: Swift.Error, Equatable, CustomStringConvertible {
        let description: String
    }
}
