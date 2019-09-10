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

import Logging
import NIO
@testable import SwiftAwsLambda
import XCTest

func runLambda(behavior: LambdaServerBehavior, handler: LambdaHandler) throws -> LambdaRunResult {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    let logger = Logger(label: "TestLogger")
    let runner = LambdaRunner(eventLoopGroup: eventLoopGroup, lambdaHandler: handler)
    let server = try MockLambdaServer(behavior: behavior).start().wait()
    defer {
        XCTAssertNoThrow(try server.stop().wait())
        XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
    }
    do {
        try runner.initialize(logger: logger).wait()
    } catch {
        return .failure(error)
    }
    let result = try runner.run(logger: logger).wait()
    return result
}

func assertRunLambdaResult(result: LambdaRunResult, shouldFailWithError: Error? = nil) {
    switch result {
    case .success:
        if shouldFailWithError != nil {
            XCTFail("should fail with \(shouldFailWithError!)")
        }
    case .failure(let error):
        if shouldFailWithError == nil {
            XCTFail("should succeed, but failed with \(error)")
            break // TODO: not sure why the assertion does not break
        }
        XCTAssertEqual(shouldFailWithError?.localizedDescription, error.localizedDescription, "expected error to mactch")
    }
}

class EchoHandler: LambdaHandler {
    var initializeCalls = 0

    func initialize(callback: @escaping LambdaInitCallBack) {
        self.initializeCalls += 1
        callback(.success(()))
    }

    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        callback(.success(payload))
    }
}

class FailedHandler: LambdaHandler {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        callback(.failure(FailedHandlerError(description: self.reason)))
    }

    struct FailedHandlerError: Error, CustomStringConvertible {
        let description: String
    }
}

class FailedInitializerHandler: LambdaHandler {
    let initError: FailedInitializerError

    public init(_ reason: String) {
        self.initError = FailedInitializerError(description: reason)
    }

    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        callback(.success(payload))
    }

    func initialize(callback: @escaping LambdaInitCallBack) {
        callback(.failure(self.initError))
    }

    public struct FailedInitializerError: Error, CustomStringConvertible {
        let description: String
    }
}
