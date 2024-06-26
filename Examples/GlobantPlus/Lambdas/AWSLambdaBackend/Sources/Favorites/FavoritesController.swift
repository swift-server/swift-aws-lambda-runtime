import Foundation
import AWSLambdaRuntime
import AWSLambdaEvents

@main
struct FavoritesController: SimpleLambdaHandler {
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        guard let body = event.body else {
            context.logger.error("🚨 No body at request")
            throw BackendError.emptyParameter
        }
        
        let jsonDecoder = JSONDecoder()
        
        guard let requestData = body.data(using: .utf8),
              let favorite = try? jsonDecoder.decode(Favorite.self, from: requestData)
        else
        {
            let message = "🚨 body data is not in the expected format"
            
            context.logger.error("\(message)")
            return APIGatewayV2Response(statusCode: .badRequest, body: message)
        }
          
        var command: FavoriteCommand?
        
        switch event.context.http.method {
            case .POST:
                command = FavoritePOSTCommand(parameter: favorite,
                                              repository: DependencyManager.makeInsertRepository())
                
                context.logger.info("POST \(favorite)")
            case .DELETE:
                command = FavoriteDELETECommand(parameter: favorite,
                                                repository: DependencyManager.makeDeleteRepository())
                
                context.logger.info("DELETE \(favorite)")
            default:
                context.logger.error("🚨 Unexpected HTTP method")
                return APIGatewayV2Response(statusCode: .methodNotAllowed)
        }
        
        try command?.execute()
        
        let apiResponse = APIGatewayV2Response(statusCode: .ok, body: "OK 😜")
        
        return apiResponse
    }
}
