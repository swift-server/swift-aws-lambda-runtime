import Foundation
import Resty

class AmazonFavoriteTrainingBaseRepository {
    func process(mediaID: Int, forUser userID: String, httpMethod verb: NetworkRequest.HttpMethod) async throws {
        let resty = Resty()
        
        let amazonFavorite = AmazonFavorite(media: mediaID, user: userID)
        
        let favoriteRequest = NetworkRequest(
            httpHeaders: [ "Content-Type" : "application/json" ],
            body: amazonFavorite.encoded(),
            httpMethod: verb)
        
        let favoriteResponse = try await resty.fetch(endpoint: AmazonFavoriteEndpoint.favorite, withParameters: favoriteRequest)
        
        if favoriteResponse.httpCodeResponse != 200 {
            throw GlobantPlusError.dataSourceFailure
        }
    }
}
