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

// This functionality is designed to help with Lambda unit testing with XCTest
// For example:
//
// func test() {
//     struct MyLambda: LambdaHandler {
//         typealias Event = String
//         typealias Output = String
//
//         init(context: Lambda.InitializationContext) {}
//
//         func handle(_ event: String, context: LambdaContext) async throws -> String {
//             "echo" + event
//         }
//     }
//
//     let input = UUID().uuidString
//     var result: String?
//     XCTAssertNoThrow(result = try Lambda.test(MyLambda.self, with: input))
//     XCTAssertEqual(result, "echo" + input)
// }

@testable import AWSLambdaRuntime
@testable import AWSLambdaRuntimeCore
import Dispatch
import Logging
import NIOCore
import NIOPosix

extension Lambda {
    public struct TestConfig {
        public var requestID: String
        public var traceID: String
        public var invokedFunctionARN: String
        public var timeout: DispatchTimeInterval

        public init(requestID: String = "\(DispatchTime.now().uptimeNanoseconds)",
                    traceID: String = "Root=\(DispatchTime.now().uptimeNanoseconds);Parent=\(DispatchTime.now().uptimeNanoseconds);Sampled=1",
                    invokedFunctionARN: String = "arn:aws:lambda:us-west-1:\(DispatchTime.now().uptimeNanoseconds):function:custom-runtime",
                    timeout: DispatchTimeInterval = .seconds(5)) {
            self.requestID = requestID
            self.traceID = traceID
            self.invokedFunctionARN = invokedFunctionARN
            self.timeout = timeout
        }
    }

    public static func test<Handler: SimpleLambdaHandler>(
        _ handlerType: Handler.Type,
        with event: Handler.Event,
        using config: TestConfig = .init()
    ) async throws -> Handler.Output {
        let context = Self.makeContext(config: config)
        let handler = Handler()
        return try await handler.handle(event, context: context.1)
    }

    public static func test<Handler: LambdaHandler>(
        _ handlerType: Handler.Type,
        with event: Handler.Event,
        using config: TestConfig = .init()
    ) async throws -> Handler.Output {
        let context = Self.makeContext(config: config)
        let handler = try await Handler(context: context.0)
        return try await handler.handle(event, context: context.1)
    }

    public static func test<Handler: EventLoopLambdaHandler>(
        _ handlerType: Handler.Type,
        with event: Handler.Event,
        using config: TestConfig = .init()
    ) async throws -> Handler.Output {
        let context = Self.makeContext(config: config)
        let handler = try await Handler.makeHandler(context: context.0).get()
        return try await handler.handle(event, context: context.1).get()
    }

    public static func test<Handler: ByteBufferLambdaHandler>(
        _ handlerType: Handler.Type,
        with buffer: ByteBuffer,
        using config: TestConfig = .init()
    ) async throws -> ByteBuffer? {
        let context = Self.makeContext(config: config)
        let handler = try await Handler.makeHandler(context: context.0).get()
        return try await handler.handle(buffer, context: context.1).get()
    }

    private static func makeContext(config: TestConfig) -> (LambdaInitializationContext, LambdaContext) {
        let logger = Logger(label: "test")

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try! eventLoopGroup.syncShutdownGracefully()
        }
        let eventLoop = eventLoopGroup.next()

        let initContext = LambdaInitializationContext.__forTestsOnly(
            logger: logger,
            eventLoop: eventLoop
        )

        let context = LambdaContext.__forTestsOnly(
            requestID: config.requestID,
            traceID: config.traceID,
            invokedFunctionARN: config.invokedFunctionARN,
            timeout: config.timeout,
            logger: logger,
            eventLoop: eventLoop
        )

        return (initContext, context)
    }
}
