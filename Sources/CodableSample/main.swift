//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime
import NIO

struct Request: Codable {
    let body: String
}

struct Response: Codable {
    let body: String
}

// in this example we are receiving and responding with codables. Request and Response above are examples of how to use
// codables to model your reqeuest and response objects
struct Handler: EventLoopLambdaHandler {
    typealias In = Request
    typealias Out = Response

    func handle(context: Lambda.Context, event: Request) -> EventLoopFuture<Response> {
        // as an example, respond with the input event's reversed body
        context.eventLoop.makeSucceededFuture(Response(body: String(event.body.reversed())))
    }
}

Lambda.run(Handler())

// MARK: - this can also be expressed as a closure:

/*
 Lambda.run { (_, request: Request, callback) in
   callback(.success(Response(body: String(request.body.reversed()))))
 }
 */
