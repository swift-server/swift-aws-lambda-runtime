//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest
import NIOCore
import NIOEmbedded
import NIOHTTP1
@testable import AWSLambdaRuntimeCore
import SwiftUI

final class NewLambdaChannelHandlerTests: XCTestCase {
    let host = "192.168.0.1"

    var delegate: EmbeddedLambdaChannelHandlerDelegate!
    var handler: NewLambdaChannelHandler<EmbeddedLambdaChannelHandlerDelegate>!
    var client: EmbeddedChannel!
    var server: EmbeddedChannel!

    override func setUp() {
        self.delegate = EmbeddedLambdaChannelHandlerDelegate()
        self.handler = NewLambdaChannelHandler(delegate: self.delegate, host: "127.0.0.1")
        
        self.client = EmbeddedChannel(handler: self.handler)
        self.server = EmbeddedChannel(handlers: [
            NIOHTTPServerRequestAggregator(maxContentLength: 1024 * 1024),
        ])
        
        XCTAssertNoThrow(try self.server.pipeline.syncOperations.configureHTTPServerPipeline(position: .first))
        
        XCTAssertNoThrow(try self.server.bind(to: .init(ipAddress: "127.0.0.1", port: 0), promise: nil))
        XCTAssertNoThrow(try self.client.connect(to: .init(ipAddress: "127.0.0.1", port: 0), promise: nil))
    }
    
    func testPipelineRequests() {
        self.handler.sendRequest(.next)
        
        self.assertInteract()
        
        var nextRequest: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(nextRequest = try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
        XCTAssertEqual(nextRequest?.head.uri, "/2018-06-01/runtime/invocation/next")
        XCTAssertEqual(nextRequest?.head.method, .GET)
        
        XCTAssertNil(try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
        
        let requestID = LambdaRequestID()
        let traceID = "foo"
        let functionARN = "arn"
        let deadline = UInt(Date().timeIntervalSince1970 * 1000) + 3000
        let requestBody = ByteBuffer(string: "foo bar")
        
        XCTAssertNoThrow(try self.server.writeOutboundInvocation(
            requestID: requestID,
            traceID: traceID,
            functionARN: functionARN,
            deadline: deadline,
            body: requestBody
        ))
        
        self.assertInteract()
        
        var response: (Invocation, ByteBuffer)?
        XCTAssertNoThrow(response = try self.delegate.readNextResponse())
        
        XCTAssertEqual(response?.0.requestID, requestID.lowercased)
        XCTAssertEqual(response?.0.traceID, traceID)
        XCTAssertEqual(response?.0.invokedFunctionARN, functionARN)
        XCTAssertEqual(response?.0.deadlineInMillisSinceEpoch, Int64(deadline))
        XCTAssertEqual(response?.1, requestBody)
        
        let responseBody = ByteBuffer(string: "hello world")
        
        self.handler.sendRequest(.invocationResponse(requestID, responseBody))
        
        self.assertInteract()
        
        var responseRequest: NIOHTTPServerRequestFull?
        XCTAssertNoThrow(responseRequest = try self.server.readInbound(as: NIOHTTPServerRequestFull.self))
        XCTAssertEqual(responseRequest?.head.uri, "/2018-06-01/runtime/invocation/\(requestID.lowercased)/response")
        XCTAssertEqual(responseRequest?.head.method, .POST)
        XCTAssertEqual(responseRequest?.body, responseBody)
    }
    
    func assertInteract(file: StaticString = #file, line: UInt = #line) {
        XCTAssertNoThrow(try {
            while let clientBuffer = try self.client.readOutbound(as: ByteBuffer.self) {
                try self.server.writeInbound(clientBuffer)
            }
            
            while let serverBuffer = try self.server.readOutbound(as: ByteBuffer.self) {
                try self.client.writeInbound(serverBuffer)
            }
        }(), file: file, line: line)
    }
}

final class EmbeddedLambdaChannelHandlerDelegate: LambdaChannelHandlerDelegate {
    
    enum Error: Swift.Error {
        case missingEvent
        case wrongEventType
        case wrongResponseType
    }
    
    private enum Event {
        case channelInactive
        case error(Swift.Error)
        case response(ControlPlaneResponse)
    }
    
    private var events: CircularBuffer<Event>
    
    init() {
        self.events = CircularBuffer(initialCapacity: 8)
    }
    
    func channelInactive() {
        self.events.append(.channelInactive)
    }
    
    func errorCaught(_ error: Swift.Error) {
        self.events.append(.error(error))
    }
    
    func responseReceived(_ response: ControlPlaneResponse) {
        self.events.append(.response(response))
    }
    
    func readResponse() throws -> ControlPlaneResponse {
        guard case .response(let response) = try self.popNextEvent() else {
            throw Error.wrongEventType
        }
        return response
    }
    
    func readNextResponse() throws -> (Invocation, ByteBuffer) {
        guard case .next(let invocation, let body) = try self.readResponse() else {
            throw Error.wrongResponseType
        }
        return (invocation, body)
    }
    
    func assertAcceptResponse() throws {
        guard case .accepted = try self.readResponse() else {
            throw Error.wrongResponseType
        }
    }
    
    func readErrorResponse() throws -> ErrorResponse {
        guard case .error(let errorResponse) = try self.readResponse() else {
            throw Error.wrongResponseType
        }
        return errorResponse
    }
    
    func readError() throws -> Swift.Error {
        guard case .error(let error) = try self.popNextEvent() else {
            throw Error.wrongEventType
        }
        return error
    }
    
    func assertChannelInactive() throws {
        guard case .channelInactive = try self.popNextEvent() else {
            throw Error.wrongEventType
        }
    }
    
    private func popNextEvent() throws -> Event {
        guard let event = self.events.popFirst() else {
            throw Error.missingEvent
        }
        return event
    }
}

extension EmbeddedChannel {
    
    func writeOutboundInvocation(
        requestID: LambdaRequestID = LambdaRequestID(),
        traceID: String = "Root=\(DispatchTime.now().uptimeNanoseconds);Parent=\(DispatchTime.now().uptimeNanoseconds);Sampled=1",
        functionARN: String = "",
        deadline: UInt = UInt(Date().timeIntervalSince1970 * 1000) + 3000,
        body: ByteBuffer?
    ) throws {
        let head = HTTPResponseHead(
            version: .http1_1,
            status: .ok,
            headers: [
                "content-length": "\(body?.readableBytes ?? 0)",
                "lambda-runtime-deadline-ms": "\(deadline)",
                "lambda-runtime-trace-id": "\(traceID)",
                "lambda-runtime-aws-request-id": "\(requestID)",
                "lambda-runtime-invoked-function-arn": "\(functionARN)"
            ]
        )
        
        try self.writeOutbound(HTTPServerResponsePart.head(head))
        if let body = body {
            try self.writeOutbound(HTTPServerResponsePart.body(.byteBuffer(body)))
        }
        try self.writeOutbound(HTTPServerResponsePart.end(nil))
    }
}
