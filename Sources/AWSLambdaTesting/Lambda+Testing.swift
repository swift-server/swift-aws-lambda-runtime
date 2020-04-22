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

// @testable for access of internal functions - this would only work for testing by design
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
        try Self.test(StringLambdaClosureWrapper(closure), config: config, with: payload)
    }

    public static func test(_ closure: @escaping StringVoidLambdaClosure,
                            with payload: String,
                            using config: TestConfig = .init()) throws {
        _ = try Self.test(StringVoidLambdaClosureWrapper(closure), config: config, with: payload)
    }

    public static func test<In: Decodable, Out: Encodable>(
        _ closure: @escaping CodableLambdaClosure<In, Out>,
        with payload: In,
        using config: TestConfig = .init()
    ) throws -> Out {
        try Self.test(CodableLambdaClosureWrapper(closure), config: config, with: payload)
    }

    public static func test<In: Decodable>(
        _ closure: @escaping CodableVoidLambdaClosure<In>,
        with payload: In,
        using config: TestConfig = .init()
    ) throws {
        _ = try Self.test(CodableVoidLambdaClosureWrapper(closure), config: config, with: payload)
    }

    public static func test<In, Out, Handler: EventLoopLambdaHandler>(
        _ handler: Handler,
        config: TestConfig = .init(),
        with payload: In
    ) throws -> Out where Handler.In == In, Handler.Out == Out {
        let logger = Logger(label: "test")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let eventLoop = eventLoopGroup.next()

        let context = Context(requestId: config.requestId,
                              traceId: config.traceId,
                              invokedFunctionArn: config.invokedFunctionArn,
                              deadline: .now() + config.timeout,
                              logger: logger,
                              eventLoop: eventLoop)

        let result = try eventLoop.flatSubmit {
            handler.handle(context: context, payload: payload)
        }.wait()

        try eventLoopGroup.syncShutdownGracefully()
        return result
    }
}
