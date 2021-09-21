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

// in this example we are receiving and responding with strings
struct Handler: EventLoopLambdaHandler {
    typealias Event = String
    typealias Output = String

    func handle(_ event: String, context: Lambda.Context) -> EventLoopFuture<String> {
        // as an example, respond with the event's reversed body
        context.eventLoop.makeSucceededFuture(String(event.reversed()))
    }
}

Lambda.run { $0.eventLoop.makeSucceededFuture(Handler()) }
