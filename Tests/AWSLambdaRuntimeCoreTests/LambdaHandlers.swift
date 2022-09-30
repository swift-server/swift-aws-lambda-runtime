//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
import XCTest

struct EchoHandler: EventLoopLambdaHandler {
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<EchoHandler> {
        context.eventLoop.makeSucceededFuture(EchoHandler())
    }

    func handle(event: String, context: LambdaContext) -> EventLoopFuture<String> {
        context.eventLoop.makeSucceededFuture(event)
    }
}

struct StartupError: Error {}

struct StartupErrorHandler: EventLoopLambdaHandler {
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<StartupErrorHandler> {
        context.eventLoop.makeFailedFuture(StartupError())
    }

    func handle(event: String, context: LambdaContext) -> EventLoopFuture<String> {
        XCTFail("Must never be called")
        return context.eventLoop.makeSucceededFuture(event)
    }
}

struct RuntimeError: Error {}

struct RuntimeErrorHandler: EventLoopLambdaHandler {
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<RuntimeErrorHandler> {
        context.eventLoop.makeSucceededFuture(RuntimeErrorHandler())
    }

    func handle(event: String, context: LambdaContext) -> EventLoopFuture<Void> {
        context.eventLoop.makeFailedFuture(RuntimeError())
    }
}
