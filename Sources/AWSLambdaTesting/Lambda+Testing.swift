//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// this is designed to only work for testing
// #if filter required for release builds which do not support @testable import
// @testable is used to access of internal functions
#if DEBUG
@testable import AWSLambdaRuntime
import Dispatch
import Logging
import NIO

extension Lambda {
    public struct TestConfig {
        public var requestId: String
        public var traceId: String
        public var invokedFunctionArn: String
        public var timeout: DispatchTimeInterval

        public init(requestId: String = "\(DispatchTime.now().uptimeNanoseconds)",
                    traceId: String = "Root=\(DispatchTime.now().uptimeNanoseconds);Parent=\(DispatchTime.now().uptimeNanoseconds);Sampled=1",
                    invokedFunctionArn: String = "arn:aws:lambda:us-west-1:\(DispatchTime.now().uptimeNanoseconds):function:custom-runtime",
                    timeout: DispatchTimeInterval = .seconds(5)) {
            self.requestId = requestId
            self.traceId = traceId
            self.invokedFunctionArn = invokedFunctionArn
            self.timeout = timeout
        }
    }

    public static func test(_ closure: @escaping StringLambdaClosure,
                            with payload: String,
                            using config: TestConfig = .init()) throws -> String {
        try Self.test(StringLambdaClosureWrapper(closure), with: payload, using: config)
    }

    public static func test(_ closure: @escaping StringVoidLambdaClosure,
                            with payload: String,
                            using config: TestConfig = .init()) throws {
        _ = try Self.test(StringVoidLambdaClosureWrapper(closure), with: payload, using: config)
    }

    public static func test<In: Decodable, Out: Encodable>(
        _ closure: @escaping CodableLambdaClosure<In, Out>,
        with payload: In,
        using config: TestConfig = .init()
    ) throws -> Out {
        try Self.test(CodableLambdaClosureWrapper(closure), with: payload, using: config)
    }

    public static func test<In: Decodable>(
        _ closure: @escaping CodableVoidLambdaClosure<In>,
        with payload: In,
        using config: TestConfig = .init()
    ) throws {
        _ = try Self.test(CodableVoidLambdaClosureWrapper(closure), with: payload, using: config)
    }

    public static func test<In, Out, Handler: EventLoopLambdaHandler>(
        _ handler: Handler,
        with payload: In,
        using config: TestConfig = .init()
    ) throws -> Out where Handler.In == In, Handler.Out == Out {
        let logger = Logger(label: "test")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try! eventLoopGroup.syncShutdownGracefully()
        }
        let eventLoop = eventLoopGroup.next()
        let context = Context(requestId: config.requestId,
                              traceId: config.traceId,
                              invokedFunctionArn: config.invokedFunctionArn,
                              deadline: .now() + config.timeout,
                              logger: logger,
                              eventLoop: eventLoop)

        return try eventLoop.flatSubmit {
            handler.handle(context: context, payload: payload)
        }.wait()
    }
}
#endif
