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
import NIOCore
import XCTest

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
class LambdaTestingTests: XCTestCase {
    func testBasics() async throws {
        struct MyLambda: LambdaHandler {
            typealias Event = String
            typealias Output = String

            func handle(_ event: String, context: LambdaContext) async throws -> String {
                event
            }
        }

        let uuid = UUID().uuidString
        let result = try await Lambda.test(MyLambda.self, with: uuid)
        XCTAssertEqual(result, uuid)
    }

    func testCodableClosure() async throws {
        struct Request: Codable {
            let name: String
        }

        struct Response: Codable {
            let message: String
        }

        struct MyLambda: LambdaHandler {
            typealias Event = Request
            typealias Output = Response

            func handle(_ event: Request, context: LambdaContext) async throws -> Response {
                Response(message: "echo" + event.name)
            }
        }

        let request = Request(name: UUID().uuidString)
        let response = try await Lambda.test(MyLambda.self, with: request)
        XCTAssertEqual(response.message, "echo" + request.name)
    }

    func testCodableVoidClosure() async throws {
        struct Request: Codable {
            let name: String
        }

        struct MyLambda: LambdaHandler {
            // DIRTY HACK: To verify the handler was actually invoked, we change a global variable.
            static var VoidLambdaHandlerInvokeCount: Int = 0

            typealias Event = Request
            typealias Output = Void

            func handle(_ event: Request, context: LambdaContext) async throws {
                Self.VoidLambdaHandlerInvokeCount += 1
            }
        }

        let request = Request(name: UUID().uuidString)
        MyLambda.VoidLambdaHandlerInvokeCount = 0
        try await Lambda.test(MyLambda.self, with: request)
        XCTAssertEqual(MyLambda.VoidLambdaHandlerInvokeCount, 1)
    }

    func testInvocationFailure() async throws {
        struct MyError: Error {}

        struct MyLambda: LambdaHandler {
            typealias Event = String
            typealias Output = Void

            func handle(_ event: String, context: LambdaContext) async throws {
                throw MyError()
            }
        }

        do {
            try await Lambda.test(MyLambda.self, with: UUID().uuidString)
            XCTFail("expected to throw")
        } catch {
            XCTAssert(error is MyError)
        }
    }

    func testAsyncLongRunning() async throws {
        struct MyLambda: LambdaHandler {
            typealias Event = String
            typealias Output = String

            func handle(_ event: String, context: LambdaContext) async throws -> String {
                try await Task.sleep(nanoseconds: 500 * 1000 * 1000)
                return event
            }
        }

        let uuid = UUID().uuidString
        let result = try await Lambda.test(MyLambda.self, with: uuid)
        XCTAssertEqual(result, uuid)
    }
}
