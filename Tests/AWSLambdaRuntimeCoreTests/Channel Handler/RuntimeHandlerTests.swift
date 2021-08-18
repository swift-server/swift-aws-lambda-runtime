//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaRuntimeCore
import Logging
import NIO
import NIOHTTP1
import XCTest

final class RuntimeHandlerTests: XCTestCase {
    struct EchoHandler: EventLoopLambdaHandler {
        typealias In = String
        typealias Out = String

        func handle(context: Lambda.Context, event: String) -> EventLoopFuture<String> {
            context.eventLoop.makeSucceededFuture(event)
        }
    }

    func testRuntimeHandler() {
        let logger = Logger(label: "Test")
        let handler = RuntimeHandler(
            configuration: .init(lifecycle: .init(maxTimes: 2)),
            logger: logger,
            factory: { $0.eventLoop.makeSucceededFuture(EchoHandler()) }
        )
        let embedded = EmbeddedChannel(handler: handler)

        let promise = embedded.eventLoop.makePromise(of: Void.self)
        XCTAssertNoThrow(try embedded.connect(to: .init(ipAddress: "127.0.0.1", port: 7000), promise: promise))
        XCTAssertNoThrow(try promise.futureResult.wait())

        XCTAssertEqual(try embedded.readOutbound(as: APIRequest.self), .next)

        let nextRequest = self.createTestHTTPInvocation()
        XCTAssertNoThrow(try embedded.writeInbound(nextRequest))
    }

    // MARK: - State Machine Tests


    // MARK: - Utilities

    func createTestHTTPInvocation() -> NIOHTTPClientResponseFull {
        let headers: HTTPHeaders = [
            "Lambda-Runtime-Aws-Request-Id": "\(UUID().uuidString)",
            "Lambda-Runtime-Trace-Id": AmazonHeaders.generateXRayTraceID(),
//            "Lambda-Runtime-Client-Context": "",
//            "Lambda-Runtime-Cognito-Identity": "",
            "Lambda-Runtime-Deadline-Ms": "\(Int64(Date().addingTimeInterval(5).timeIntervalSince1970 * 1000))",
            "Lambda-Runtime-Invoked-Function-Arn": "function:arn"
        ]

        let buffer = ByteBuffer(string: "Hello world")
        
        return NIOHTTPClientResponseFull(
            head: HTTPResponseHead(version: .http1_1, status: .ok, headers: headers),
            body: buffer
        )
    }
}

extension RuntimeHandler.StateMachine.Action: Equatable {
    public static func == (lhs: RuntimeHandler.StateMachine.Action, rhs: RuntimeHandler.StateMachine.Action) -> Bool {
        switch (lhs, rhs) {
        case (.connect(to: let lhsSocket, let lhsPromise, _), .connect(to: let rhsSocket, let rhsPromise, _)):
            guard lhsSocket == rhsSocket else {
                return false
            }
            return lhsPromise?.futureResult === rhsPromise?.futureResult
        case (.reportStartupSuccessToChannel, .reportStartupSuccessToChannel):
            return true
        case (.reportStartupFailureToChannel(_), .reportStartupFailureToChannel(_)):
            return true
        case (.getNextInvocation, .getNextInvocation):
            return true
        case (.invokeHandler(_, let lhInvocation, let lhBuffer, let lhCount), .invokeHandler(_, let rhInvocation, let rhBuffer, let rhCount)):
            return lhInvocation == rhInvocation && lhBuffer == rhBuffer && lhCount == rhCount
        case (.reportInvocationResult(let lhRequestID, let lhResult), .reportInvocationResult(let rhRequestID, let rhResult)):
            guard lhRequestID == rhRequestID else {
                return false
            }

            switch (lhResult, rhResult) {
            case (.success(let lhBuffer), .success(let rhBuffer)):
                return lhBuffer == rhBuffer
            case (.failure(_), .failure(_)):
                return true
            default:
                return false
            }
        case (.reportInitializationError(_), .reportInitializationError(_)):
            return true
        case (.closeConnection, .closeConnection):
            return true
        case (.fireChannelInactive, .fireChannelInactive):
            return true
        case (.wait, .wait):
            return true
        default:
            return false
        }
    }
}
