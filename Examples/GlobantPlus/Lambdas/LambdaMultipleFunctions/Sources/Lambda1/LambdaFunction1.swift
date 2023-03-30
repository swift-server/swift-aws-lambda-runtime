import Foundation
import AWSLambdaRuntime
import AWSLambdaRuntimeCore

@main
struct LambdaFunction1: SimpleLambdaHandler {
    func handle(_ request: String, context: LambdaContext) async throws -> String {
        return "Test function 1"
    }
}
