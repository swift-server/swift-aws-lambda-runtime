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
import XCTest

final class RuntimeHandlerTests: XCTestCase {
    struct EchoHandler: EventLoopLambdaHandler {
        typealias In = String
        typealias Out = String

        func handle(context: Lambda.Context, event: String) -> EventLoopFuture<String> {
            context.eventLoop.makeSucceededFuture(event)
        }
    }

    struct EchoError: Error {
        let message: String

        init(_ message: String) {
            self.message = message
        }
    }

    func testRuntimeHandler() {
        let logger = Logger(label: "Test")
        let handler = RuntimeHandler(
            maxTimes: 2,
            logger: logger,
            factory: { $0.eventLoop.makeSucceededFuture(EchoHandler()) }
        )
        let embedded = EmbeddedChannel(handler: handler)

        let promise = embedded.eventLoop.makePromise(of: Void.self)
        XCTAssertNoThrow(try embedded.connect(to: .init(ipAddress: "127.0.0.1", port: 7000), promise: promise))
        XCTAssertNoThrow(try promise.futureResult.wait())

        XCTAssertEqual(try embedded.readOutbound(as: RuntimeAPIRequest.self), .next)

        let (invocation, payload) = self.createTestInvocation()
        XCTAssertNoThrow(try embedded.writeInbound(RuntimeAPIResponse.next(invocation, payload)))
    }

    // MARK: - State Machine Tests

    func testStateMachineStartupSuccessTwoInvocations() {
        let embedded = EmbeddedChannel()
        let logger = Logger(label: "Test")
        let factory: Lambda.HandlerFactory = { $0.eventLoop.makeSucceededFuture(EchoHandler()) }
        var state = RuntimeHandler.StateMachine(maxTimes: 3, factory: factory)
        let socket = try! SocketAddress(ipAddress: "127.0.0.1", port: 7000)

        // --- startup
        XCTAssertEqual(state.connect(to: socket, promise: nil), .connect(to: socket, promise: nil, andInitializeHandler: factory))
        let initContext = Lambda.InitializationContext(logger: logger, eventLoop: embedded.eventLoop, allocator: embedded.allocator)
        XCTAssertEqual(try state.handlerInitialized(factory(initContext).wait()), .wait)
        XCTAssertEqual(state.connected(), .reportStartupSuccessToChannel)
        XCTAssertEqual(state.startupSuccessToChannelReported(), .getNextInvocation)

        // --- 1. invocation - success
        let (fstInvocation, fstPayload) = self.createTestInvocation()
        XCTAssertEqual(state.nextInvocationReceived(fstInvocation, fstPayload), .invokeHandler(EchoHandler(), fstInvocation, fstPayload, 1))
        XCTAssertEqual(state.invocationCompleted(.success(fstPayload)), .reportInvocationResult(requestID: fstInvocation.requestID, .success(fstPayload)))
        XCTAssertEqual(state.acceptedReceived(), .getNextInvocation)

        // --- 2. invocation - failure
        let (sndInvocation, sndPayload) = self.createTestInvocation()
        XCTAssertEqual(state.nextInvocationReceived(sndInvocation, sndPayload), .invokeHandler(EchoHandler(), sndInvocation, sndPayload, 2))
        let error = EchoError("Boom")
        XCTAssertEqual(state.invocationCompleted(.failure(error)), .reportInvocationResult(requestID: sndInvocation.requestID, .failure(error)))
        XCTAssertEqual(state.acceptedReceived(), .getNextInvocation)

        // --- 3. invocation - success
        let (thrInvocation, thrPayload) = self.createTestInvocation()
        XCTAssertEqual(state.nextInvocationReceived(thrInvocation, thrPayload), .invokeHandler(EchoHandler(), thrInvocation, thrPayload, 3))
        XCTAssertEqual(state.invocationCompleted(.success(thrPayload)), .reportInvocationResult(requestID: thrInvocation.requestID, .success(thrPayload)))
        XCTAssertEqual(state.acceptedReceived(), .closeConnection)

        // --- shutdown
        XCTAssertEqual(state.channelInactive(), .fireChannelInactive)
    }

    func testStateMachineStartupFailure() {
        let error = EchoError("Boom")
        let factory: Lambda.HandlerFactory = { $0.eventLoop.makeFailedFuture(error) }
        var state = RuntimeHandler.StateMachine(maxTimes: 3, factory: factory)
        let socket = try! SocketAddress(ipAddress: "127.0.0.1", port: 7000)

        // --- startup
        XCTAssertEqual(state.connect(to: socket, promise: nil), .connect(to: socket, promise: nil, andInitializeHandler: factory))
        XCTAssertEqual(state.handlerFailedToInitialize(error), .wait)
        XCTAssertEqual(state.connected(), .reportInitializationError(error))
        XCTAssertEqual(state.acceptedReceived(), .reportStartupFailureToChannel(error))
        XCTAssertEqual(state.startupFailureToChannelReported(), .closeConnection)
        XCTAssertEqual(state.channelInactive(), .fireChannelInactive)
    }

    // MARK: - Utilities

    func createTestInvocation() -> (Invocation, ByteBuffer) {
        let invocation = Invocation(
            requestID: UUID().uuidString,
            deadlineInMillisSinceEpoch: Int64(Date().addingTimeInterval(5).timeIntervalSince1970 * 1000),
            invokedFunctionARN: "function:arn",
            traceID: AmazonHeaders.generateXRayTraceID(),
            clientContext: nil,
            cognitoIdentity: nil
        )
        let buffer = ByteBuffer(string: "Hello world")

        return (invocation, buffer)
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
