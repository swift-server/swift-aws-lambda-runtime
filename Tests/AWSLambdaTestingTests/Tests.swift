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

#if compiler(>=5.5) && canImport(_Concurrency)
import AWSLambdaRuntime
import AWSLambdaTesting
import NIOCore
import XCTest

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
class LambdaTestingTests: XCTestCase {
    func testCodableClosure() {
        struct Request: Codable {
            let name: String
        }

        struct Response: Codable {
            let message: String
        }

        struct MyLambda: LambdaHandler {
            typealias Event = Request
            typealias Output = Response

            init(context: Lambda.InitializationContext) {}

            func handle(_ event: Request, context: LambdaContext) async throws -> Response {
                Response(message: "echo" + event.name)
            }
        }

        let request = Request(name: UUID().uuidString)
        var response: Response?
        XCTAssertNoThrow(response = try Lambda.test(MyLambda.self, with: request))
        XCTAssertEqual(response?.message, "echo" + request.name)
    }

    // DIRTY HACK: To verify the handler was actually invoked, we change a global variable.
    static var VoidLambdaHandlerInvokeCount: Int = 0
    func testCodableVoidClosure() {
        struct Request: Codable {
            let name: String
        }

        struct MyLambda: LambdaHandler {
            typealias Event = Request
            typealias Output = Void

            init(context: Lambda.InitializationContext) {}

            func handle(_ event: Request, context: LambdaContext) async throws {
                LambdaTestingTests.VoidLambdaHandlerInvokeCount += 1
            }
        }

        Self.VoidLambdaHandlerInvokeCount = 0
        let request = Request(name: UUID().uuidString)
        XCTAssertNoThrow(try Lambda.test(MyLambda.self, with: request))
        XCTAssertEqual(Self.VoidLambdaHandlerInvokeCount, 1)
    }

    func testInvocationFailure() {
        struct MyError: Error {}

        struct MyLambda: LambdaHandler {
            typealias Event = String
            typealias Output = Void

            init(context: Lambda.InitializationContext) {}

            func handle(_ event: String, context: LambdaContext) async throws {
                throw MyError()
            }
        }

        XCTAssertThrowsError(try Lambda.test(MyLambda.self, with: UUID().uuidString)) { error in
            XCTAssert(error is MyError)
        }
    }

    func testAsyncLongRunning() {
        struct MyLambda: LambdaHandler {
            typealias Event = String
            typealias Output = String

            init(context: Lambda.InitializationContext) {}

            func handle(_ event: String, context: LambdaContext) async throws -> String {
                try await Task.sleep(nanoseconds: 500 * 1000 * 1000)
                return event
            }
        }

        let uuid = UUID().uuidString
        XCTAssertEqual(try Lambda.test(MyLambda.self, with: uuid), uuid)
    }
}
#endif
