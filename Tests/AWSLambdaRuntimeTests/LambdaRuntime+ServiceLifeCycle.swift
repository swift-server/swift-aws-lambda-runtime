#if ServiceLifecycleSupport
@testable import AWSLambdaRuntime
import ServiceLifecycle
import Testing
import Logging

@Suite
struct LambdaRuntimeServiceLifecycleTests {
    @Test
    func testLambdaRuntimeGracefulShutdown() async throws {
        let runtime = LambdaRuntime {
            (event: String, context: LambdaContext) in
            "Hello \(event)"
        }

        let serviceGroup = ServiceGroup(
            services: [runtime],
            gracefulShutdownSignals: [.sigterm, .sigint],
            logger: Logger(label: "TestLambdaRuntimeGracefulShutdown")
        )
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await serviceGroup.run()
            }
            // wait a small amount to ensure we are waiting for continuation
            try await Task.sleep(for: .milliseconds(100))

            await serviceGroup.triggerGracefulShutdown()
        }
    }
}
#endif
