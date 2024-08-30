import Foundation
import Logging
import NIOCore
import Testing

@testable import AWSLambdaRuntimeCore

struct LambdaRunLoopTests {
    struct MockEchoHandler: StreamingLambdaHandler {
        func handle(
            _ event: ByteBuffer,
            responseWriter: some LambdaResponseStreamWriter,
            context: NewLambdaContext
        ) async throws {
            try await responseWriter.writeAndFinish(event)
        }
    }

    let mockClient = LambdaMockClient()
    let mockEchoHandler = MockEchoHandler()

    @Test func testRunLoop() async throws {
        _ = Task { () in
            try await Lambda.runLoop(
                runtimeClient: self.mockClient,
                handler: self.mockEchoHandler,
                logger: Logger(label: "RunLoopTest")
            )
        }

        let inputEvent = ByteBuffer(string: "Test Invocation Event")
        let response = try await self.mockClient.invoke(event: inputEvent)

        #expect(response == inputEvent)
    }
}
