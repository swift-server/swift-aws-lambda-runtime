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

struct EchoHandler: EventLoopLambdaHandler {
    typealias In = String
    typealias Out = String

    func handle(context: Lambda.Context, event: String) -> EventLoopFuture<String> {
        context.eventLoop.makeSucceededFuture(event)
    }
}

struct FailedHandler: EventLoopLambdaHandler {
    typealias In = String
    typealias Out = Void

    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context: Lambda.Context, event: String) -> EventLoopFuture<Void> {
        context.eventLoop.makeFailedFuture(TestError(self.reason))
    }
}
