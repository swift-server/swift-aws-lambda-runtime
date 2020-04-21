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
    public static func test(_ closure: @escaping StringLambdaClosure,
                            with payload: String,
                            _ body: @escaping (Result<String, Error>) -> Void) {
        Self.test(StringLambdaClosureWrapper(closure), with: payload, body)
    }

    public static func test(_ closure: @escaping StringVoidLambdaClosure,
                            with payload: String,
                            _ body: @escaping (Result<Void, Error>) -> Void) {
        Self.test(StringVoidLambdaClosureWrapper(closure), with: payload, body)
    }

    public static func test<In: Decodable, Out: Encodable>(_ closure: @escaping CodableLambdaClosure<In, Out>,
                                                           with payload: In,
                                                           _ body: @escaping (Result<Out, Error>) -> Void) {
        Self.test(CodableLambdaClosureWrapper(closure), with: payload, body)
    }

    public static func test<In: Decodable>(_ closure: @escaping CodableVoidLambdaClosure<In>,
                                           with payload: In,
                                           _ body: @escaping (Result<Void, Error>) -> Void) {
        Self.test(CodableVoidLambdaClosureWrapper(closure), with: payload, body)
    }

    public static func test<In, Out, Handler: EventLoopLambdaHandler>(_ handler: Handler,
                                                                      with payload: In,
                                                                      _ body: @escaping (Result<Out, Error>) -> Void) where Handler.In == In, Handler.Out == Out {
        let logger = Logger(label: "test")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let context = Context(requestId: "\(DispatchTime.now().uptimeNanoseconds)",
                              traceId: "Root=\(DispatchTime.now().uptimeNanoseconds);Parent=\(DispatchTime.now().uptimeNanoseconds);Sampled=1",
                              invokedFunctionArn: "arn:aws:lambda:us-west-1:\(DispatchTime.now().uptimeNanoseconds):function:custom-runtime",
                              deadline: .now() + 5,
                              logger: logger,
                              eventLoop: eventLoopGroup.next())
        handler.handle(context: context, payload: payload).whenComplete { result in
            body(result)
        }
    }
}
