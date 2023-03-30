import Foundation
import Resty

public final class MovieDB {
    let resty = Resty()
    let jsonDecoder = JSONDecoder()
    let authorizationMode: AuthorizationMode
    
    var languageCode: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    public init(authorization mode: AuthorizationMode) {
        self.authorizationMode = mode
        jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.movieDatabaseFormatter)
    }

    public convenience init(apiKey value: String) {
        self.init(authorization: .apiKey(key: value))
    }
    
    public convenience init(token bearer: String) {
        self.init(authorization: .header(token: bearer))
    }
    
    internal func get(endpoint movieDBEndpoint: Endpoint, withParameters parameters: [QueryParameter]? = nil) async throws -> NetworkResponse {
        var request = NetworkRequest()
    
        switch authorizationMode {
            case .header(let token):
                request.headers = [
                    "Authorization" : "Bearer \(token)"
                ]
            case .apiKey(let key):
                request.queryParameters = [ ApiQueryParameter.apiKey(value: key) ]
        }
        
        // Default language
        request.queryParameters = (request.queryParameters ?? []) + [ ApiQueryParameter.language(code: self.languageCode) ]
        
        // Request parameters
        if let parameters {
            request.queryParameters?.append(contentsOf: parameters)
        }
        
        return try await resty.fetch(endpoint: movieDBEndpoint, withParameters: request)
    }
}
