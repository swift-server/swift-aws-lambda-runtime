import Foundation
import AWSLambdaRuntime

@main
final class AWSLambdaBasic: SimpleLambdaHandler {
    
    func handle(_ request: BasicRequest, context: LambdaContext) async throws -> BasicResponse {
        let response = BasicResponse(name: request.name)
        
        return response
    }
}
