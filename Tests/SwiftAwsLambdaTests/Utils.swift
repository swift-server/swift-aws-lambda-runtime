//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@testable import SwiftAwsLambda
import XCTest

func runLambda(behavior: LambdaServerBehavior, handler: LambdaHandler) throws -> RunLambdaResult {
    /* let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
     let server = MockLambdaServer(behavior: behavior)
     return server.start().hopTo(eventLoop: eventLoop).then { _ in
     let runner = LambdaRunner(eventLoop: eventLoop, lambdaHandler: handler)
     return runner.run().then { result in
     server.stop().hopTo(eventLoop: eventLoop).then { _ in
     print("\(server) stopped")
     return eventLoop.newSucceededFuture(result: result)
     }
     }
     } */

    let runner = LambdaRunner(handler)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    let result = try runner.run().wait()
    try server.stop().wait()
    return result
}

func assertRunLambdaResult(result: RunLambdaResult, shouldFailWithError: Error? = nil) {
    switch result {
    case .success:
        if nil != shouldFailWithError {
            XCTFail("should fail with \(shouldFailWithError!)")
        }
    case let .failure(error):
        if nil == shouldFailWithError {
            XCTFail("should succeed, but failed with \(error)")
            break // TODO: not sure why the assertion does not break
        }
        XCTAssertEqual(shouldFailWithError?.localizedDescription, error.localizedDescription, "expected error to mactch")
    }
}

class EchoHandler: LambdaHandler {
    func handle(context _: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        callback(.success(payload))
    }
}

class FailedHandler: LambdaHandler {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context _: LambdaContext, payload _: [UInt8], callback: @escaping LambdaCallback) {
        callback(.failure(reason))
    }
}
