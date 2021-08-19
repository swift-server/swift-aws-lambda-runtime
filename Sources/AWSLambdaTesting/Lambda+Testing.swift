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
// #if filter required for release builds which do not support @testable import
// @testable is used to access of internal functions
// For exmaple:
//
// func test() {
//     struct MyLambda: EventLoopLambdaHandler {
//         typealias In = String
//         typealias Out = String
//
//         func handle(context: Lambda.Context, event: String) -> EventLoopFuture<String> {
//             return context.eventLoop.makeSucceededFuture("echo" + event)
//         }
//     }
//
//     let input = UUID().uuidString
//     var result: String?
//     XCTAssertNoThrow(result = try Lambda.test(MyLambda(), with: input))
//     XCTAssertEqual(result, "echo" + input)
// }

#if DEBUG
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
                    timeout: DispatchTimeInterval = .seconds(5))
        {
            self.requestID = requestID
            self.traceID = traceID
            self.invokedFunctionARN = invokedFunctionARN
            self.timeout = timeout
        }
    }

    public static func test<In, Out, Handler: EventLoopLambdaHandler>(
        _ handler: Handler,
        with event: In,
        using config: TestConfig = .init()
    ) throws -> Out where Handler.In == In, Handler.Out == Out {
        let logger = Logger(label: "test")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try! eventLoopGroup.syncShutdownGracefully()
        }
        let eventLoop = eventLoopGroup.next()
        let context = Context(requestID: config.requestID,
                              traceID: config.traceID,
                              invokedFunctionARN: config.invokedFunctionARN,
                              deadline: .now() + config.timeout,
                              logger: logger,
                              eventLoop: eventLoop,
                              allocator: ByteBufferAllocator())

        return try eventLoop.flatSubmit {
            handler.handle(context: context, event: event)
        }.wait()
    }
}
#endif
