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

class LambdaRunnerTest: XCTestCase {
    func testSuccess() throws {
        struct Behavior: LambdaServerBehavior {
            let requestId = UUID().uuidString
            let payload = "hello"
            func getWork() -> GetWorkResult {
                return .success((self.requestId, self.payload))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
                XCTAssertEqual(self.payload, response, "expecting response to match")
                return .success
            }

            func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertNoThrow(try runLambda(behavior: Behavior(), handler: EchoHandler()))
    }

    func testFailure() throws {
        struct Behavior: LambdaServerBehavior {
            static let error = "boom"
            let requestId = UUID().uuidString
            func getWork() -> GetWorkResult {
                return .success((requestId: self.requestId, payload: "hello"))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTFail("should report error")
                return .failure(.internalServerError)
            }

            func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
                XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
                XCTAssertEqual(Behavior.error, error.errorMessage, "expecting error to match")
                return .success(())
            }

            func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }
        XCTAssertNoThrow(try runLambda(behavior: Behavior(), handler: FailedHandler(Behavior.error)))
    }

    func testConcurrency() throws {
        struct Behavior: LambdaServerBehavior {
            let requestId = UUID().uuidString
            let payload = "hello"
            func getWork() -> GetWorkResult {
                return .success((self.requestId, self.payload))
            }

            func processResponse(requestId: String, response: String) -> ProcessResponseResult {
                XCTAssertEqual(self.requestId, requestId, "expecting requestId to match")
                XCTAssertEqual(self.payload, response, "expecting response to match")
                return .success
            }

            func processError(requestId: String, error: ErrorResponse) -> ProcessErrorResult {
                XCTFail("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> ProcessInitErrorResult {
                XCTFail("should not report init error")
                return .failure(.internalServerError)
            }
        }

        let server = try MockLambdaServer(behavior: Behavior()).start().wait()
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        let logger = Logger(label: "TestLogger")
        let configuration = Lambda.Configuration(runtimeEngine: .init(requestTimeout: .seconds(1)))
        let runner = LambdaRunner(eventLoop: eventLoopGroup.next(), configuration: configuration, lambdaHandler: EchoHandler())
        XCTAssertNoThrow(try runner.initialize(logger: logger).wait())

        let total = 50
        let group = DispatchGroup()
        for _ in 0 ..< total {
            group.enter()
            DispatchQueue.global().async {
                runner.run(logger: logger).whenComplete { result in
                    if case .failure(let error) = result {
                        XCTFail("should not fail, but failed with \(error)")
                    }
                    group.leave()
                }
            }
        }

        group.wait()
    }
}
