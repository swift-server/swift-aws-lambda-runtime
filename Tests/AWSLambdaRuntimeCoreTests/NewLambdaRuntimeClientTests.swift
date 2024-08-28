//
//  NewLambdaRuntimeClientTests.swift
//  swift-aws-lambda-runtime
//
//  Created by Fabian Fett on 28.08.24.
//

import Testing
import NIOCore
import NIOPosix
import Logging
import struct Foundation.UUID
@testable import AWSLambdaRuntimeCore

@Suite
struct NewLambdaRuntimeClientTests {

    let logger = Logger(label: "NewLambdaClientRuntimeTest")

    init() {

    }

    @Test
    func testSimpleInvocations() async throws {
        struct HappyBehavior: LambdaServerBehavior {
            let requestId = UUID().uuidString
            let event = "hello"

            func getInvocation() -> GetInvocationResult {
                .success((self.requestId, self.event))
            }

            func processResponse(requestId: String, response: String?) -> Result<Void, ProcessResponseError> {
                #expect(self.requestId == requestId)
                #expect(self.event == response)
                return .success(())
            }

            func processError(requestId: String, error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                Issue.record("should not report error")
                return .failure(.internalServerError)
            }

            func processInitError(error: ErrorResponse) -> Result<Void, ProcessErrorError> {
                Issue.record("should not report init error")
                return .failure(.internalServerError)
            }
        }

        try await self.withMockServer(behaviour: HappyBehavior()) { mockServer, eventLoopGroup in
            let configuration = NewLambdaRuntimeClient.Configuration(ip: "127.0.0.1", port: 7000)

            try await NewLambdaRuntimeClient.withRuntimeClient(
                configuration: configuration, eventLoop: eventLoopGroup.next(),
                logger: self.logger
            ) { runtimeClient in
                do {
                    let (invocation, writer) = try await runtimeClient.nextInvocation()
                    let expected = ByteBuffer(string: "hello")
                    #expect(invocation.event == expected)
                    try await writer.writeAndFinish(expected)
                }

                do {
                    let (invocation, writer) = try await runtimeClient.nextInvocation()
                    let expected = ByteBuffer(string: "hello")
                    #expect(invocation.event == expected)
                    try await writer.write(ByteBuffer(string: "h"))
                    try await writer.write(ByteBuffer(string: "e"))
                    try await writer.write(ByteBuffer(string: "l"))
                    try await writer.write(ByteBuffer(string: "l"))
                    try await writer.write(ByteBuffer(string: "o"))
                    try await writer.finish()
                }
            }
        }
    }

    func withMockServer<Result>(behaviour: some LambdaServerBehavior, _ body: (MockLambdaServer, MultiThreadedEventLoopGroup) async throws -> Result) async throws -> Result {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = MockLambdaServer(behavior: behaviour)
        _ = try await server.start().get()

        let result: Swift.Result<Result, any Error>
        do {
            result = .success(try await body(server, eventLoopGroup))
        } catch {
            result = .failure(error)
        }

        try? await server.stop().get()
        try? await eventLoopGroup.shutdownGracefully()

        return try result.get()
    }

}
