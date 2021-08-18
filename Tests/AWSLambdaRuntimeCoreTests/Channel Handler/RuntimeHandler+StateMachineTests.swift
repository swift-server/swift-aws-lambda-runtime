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

final class RuntimeHandler_StateMachineTests: XCTestCase {
    
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
    
    struct EchoError: Error {
        let message: String

        init(_ message: String) {
            self.message = message
        }
    }

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
