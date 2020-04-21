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
        Lambda.test(myLambda, with: request) { result in
            switch result {
            case .failure(let error):
                XCTFail("expected to succeed but failed with \(error)")
            case .success(let response):
                XCTAssertEqual(response.message, "echo" + request.name)
            }
        }
    }

    func testCodableVoidClosure() {
        struct Request: Codable {
            let name: String
        }

        let myLambda = { (_: Lambda.Context, _: Request, callback: (Result<Void, Error>) -> Void) in
            callback(.success(()))
        }

        let request = Request(name: UUID().uuidString)
        Lambda.test(myLambda, with: request) { result in
            switch result {
            case .failure(let error):
                XCTFail("expected to succeed but failed with \(error)")
            case .success:
                break
            }
        }
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
                callback(.success(Response(message: "echo" + payload.name)))
            }
        }

        let request = Request(name: UUID().uuidString)
        Lambda.test(MyLambda(), with: request) { result in
            switch result {
            case .failure(let error):
                XCTFail("expected to succeed but failed with \(error)")
            case .success(let response):
                XCTAssertEqual(response.message, "echo" + request.name)
            }
        }
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

        Lambda.test(MyLambda(), with: UUID().uuidString) { result in
            switch result {
            case .failure(let error):
                XCTAssert(error is MyError)
            case .success:
                XCTFail("expected to fail but succeeded")
            }
        }
    }
}
