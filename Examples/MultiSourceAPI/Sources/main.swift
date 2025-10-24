import AWSLambdaEvents
import AWSLambdaRuntime
import HTTPTypes
import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct MultiSourceHandler: StreamingLambdaHandler {
    func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {
        let decoder = JSONDecoder()
        let data = Data(event.readableBytesView)
        
        // Try to decode as ALBTargetGroupRequest first
        if let albRequest = try? decoder.decode(ALBTargetGroupRequest.self, from: data) {
            context.logger.info("Received ALB request to path: \(albRequest.path)")
            
            let response = ALBTargetGroupResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: "{\"source\":\"ALB\",\"path\":\"\(albRequest.path)\"}"
            )
            
            let encoder = JSONEncoder()
            let responseData = try encoder.encode(response)
            try await responseWriter.write(ByteBuffer(bytes: responseData))
            try await responseWriter.finish()
            return
        }
        
        // Try to decode as APIGatewayV2Request
        if let apiGwRequest = try? decoder.decode(APIGatewayV2Request.self, from: data) {
            context.logger.info("Received API Gateway V2 request to path: \(apiGwRequest.rawPath)")
            
            let response = APIGatewayV2Response(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: "{\"source\":\"APIGatewayV2\",\"path\":\"\(apiGwRequest.rawPath)\"}"
            )
            
            let encoder = JSONEncoder()
            let responseData = try encoder.encode(response)
            try await responseWriter.write(ByteBuffer(bytes: responseData))
            try await responseWriter.finish()
            return
        }
        
        // Unknown event type
        context.logger.error("Unable to decode event as ALB or API Gateway V2 request")
        throw LambdaError.invalidEvent
    }
}

enum LambdaError: Error {
    case invalidEvent
}

let runtime = LambdaRuntime(handler: MultiSourceHandler())
try await runtime.run()
