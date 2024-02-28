import Foundation

public struct NetworkRequest {
    public enum HttpMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }
    
    public var queryParameters: [QueryParameter]?
    public var headers: [String : String]?
    public var payload: Data?
    public var method: NetworkRequest.HttpMethod = .get
    
    public init(parameters: [QueryParameter]? = nil, httpHeaders: [String : String]? = nil, body payload: Data? = nil, httpMethod: NetworkRequest.HttpMethod = .get) {
        self.queryParameters = parameters
        self.headers = httpHeaders
        self.payload = payload
        self.method = httpMethod
    }
    
    func makeURLRequest(for endpoint: Endpoint) -> URLRequest? {
        guard let url = URL(string: endpoint.path),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        
        if let parameters = queryParameters, !parameters.isEmpty {
            components.queryItems = parameters.map({ $0.queryItem })
        }
        
        guard let url = components.url else {
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        
        if let headers = headers {
            headers.forEach({ request.addValue($0.value, forHTTPHeaderField: $0.key) })
        }
        
        if let body = payload {
            request.httpBody = body
        }
        
        request.httpMethod = self.method.rawValue
        
        return request
    }
}
