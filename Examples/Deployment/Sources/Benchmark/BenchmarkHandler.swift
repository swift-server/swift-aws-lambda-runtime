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

import AWSLambdaRuntimeCore
import NIOCore

// If you would like to benchmark Swift's Lambda Runtime,
// use this example which is more performant.
// `EventLoopLambdaHandler` does not offload the Lambda processing to a separate thread
// while the closure-based handlers do.

@main
struct BenchmarkHandler: EventLoopLambdaHandler {
    typealias Event = String
    typealias Output = String

    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self> {
        context.eventLoop.makeSucceededFuture(BenchmarkHandler())
    }

    func handle(_ event: String, context: LambdaContext) -> EventLoopFuture<String> {
        context.eventLoop.makeSucceededFuture("hello, world!")
    }
}
