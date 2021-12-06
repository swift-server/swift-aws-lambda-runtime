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

#if compiler(>=5.5) && canImport(_Concurrency)
import AWSLambdaRuntime
import Dispatch
import Logging
import NIOCore
import NIOPosix

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
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

    public static func test<Handler: LambdaHandler>(
        _ handlerType: Handler.Type,
        with event: Handler.Event,
        using config: TestConfig = .init()
    ) throws -> Handler.Output {
        let logger = Logger(label: "test")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try! eventLoopGroup.syncShutdownGracefully()
        }
        let eventLoop = eventLoopGroup.next()

        let promise = eventLoop.makePromise(of: Handler.self)
        let initContext = Lambda.InitializationContext.__forTestsOnly(
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

        promise.completeWithTask {
            try await Handler(context: initContext)
        }
        let handler = try promise.futureResult.wait()

        return try eventLoop.flatSubmit {
            handler.handle(event, context: context)
        }.wait()
    }
}
#endif
