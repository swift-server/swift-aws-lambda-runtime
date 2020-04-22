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

import AWSLambdaRuntime
import AWSLambdaTesting
import NIO
import XCTest

class LambdaTestingTests: XCTestCase {
    func testCodableClosure() {
        struct Request: Codable {
            let name: String
        }

        struct Response: Codable {
            let message: String
        }

        let myLambda = { (_: Lambda.Context, request: Request, callback: (Result<Response, Error>) -> Void) in
            callback(.success(Response(message: "echo" + request.name)))
        }

        let request = Request(name: UUID().uuidString)
        var response: Response?
        XCTAssertNoThrow(response = try Lambda.test(myLambda, with: request))
        XCTAssertEqual(response?.message, "echo" + request.name)
    }

    func testCodableVoidClosure() {
        struct Request: Codable {
            let name: String
        }

        let myLambda = { (_: Lambda.Context, _: Request, callback: (Result<Void, Error>) -> Void) in
            callback(.success(()))
        }

        let request = Request(name: UUID().uuidString)
        XCTAssertNoThrow(try Lambda.test(myLambda, with: request))
    }

    func testLambdaHandler() {
        struct Request: Codable {
            let name: String
        }

        struct Response: Codable {
            let message: String
        }

        struct MyLambda: LambdaHandler {
            typealias In = Request
            typealias Out = Response

            func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
                XCTAssertFalse(context.eventLoop.inEventLoop)
                callback(.success(Response(message: "echo" + payload.name)))
            }
        }

        let request = Request(name: UUID().uuidString)
        var response: Response?
        XCTAssertNoThrow(response = try Lambda.test(MyLambda(), with: request))
        XCTAssertEqual(response?.message, "echo" + request.name)
    }

    func testEventLoopLambdaHandler() {
        struct MyLambda: EventLoopLambdaHandler {
            typealias In = String
            typealias Out = String

            func handle(context: Lambda.Context, payload: String) -> EventLoopFuture<String> {
                XCTAssertTrue(context.eventLoop.inEventLoop)
                return context.eventLoop.makeSucceededFuture("echo" + payload)
            }
        }

        let input = UUID().uuidString
        var result: String?
        XCTAssertNoThrow(result = try Lambda.test(MyLambda(), with: input))
        XCTAssertEqual(result, "echo" + input)
    }

    func testFailure() {
        struct MyError: Error {}

        struct MyLambda: LambdaHandler {
            typealias In = String
            typealias Out = Void

            func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
                callback(.failure(MyError()))
            }
        }

        XCTAssertThrowsError(try Lambda.test(MyLambda(), with: UUID().uuidString)) { error in
            XCTAssert(error is MyError)
        }
    }

    func testAsyncLongRunning() {
        var executed: Bool = false
        let myLambda = { (_: Lambda.Context, _: String, callback: @escaping (Result<Void, Error>) -> Void) in
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                executed = true
                callback(.success(()))
            }
        }

        XCTAssertNoThrow(try Lambda.test(myLambda, with: UUID().uuidString))
        XCTAssertTrue(executed)
    }

    func testConfigValues() {
        let config = Lambda.TestConfig(
            requestId: "abc123",
            traceId: "hahahihi",
            invokedFunctionArn: "arn:hihi",
            timeout: 4
        )

        let myLambda = { (ctx: Lambda.Context, _: String, callback: @escaping (Result<Void, Error>) -> Void) in
            XCTAssertEqual(ctx.requestId, config.requestId)
            XCTAssertEqual(ctx.traceId, config.traceId)
            XCTAssertEqual(ctx.invokedFunctionArn, config.invokedFunctionArn)

            let secondsSinceEpoch = Double(Int64(bitPattern: ctx.deadline.rawValue)) / -1_000_000_000
            XCTAssertLessThanOrEqual(Date(timeIntervalSince1970: secondsSinceEpoch).timeIntervalSinceNow, config.timeout)

            callback(.success(()))
        }

        XCTAssertNoThrow(try Lambda.test(myLambda, config: config, with: UUID().uuidString))
    }
}
