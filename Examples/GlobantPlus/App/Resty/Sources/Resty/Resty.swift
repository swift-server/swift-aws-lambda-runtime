import Foundation

public final class Resty {
    private let httpSession: URLSession
    
    public init() {
        self.httpSession =  URLSession.shared
    }
    
    public func fetch(endpoint: Endpoint) async throws -> NetworkResponse {
        let parameters = NetworkRequest(httpMethod: .get)
        return try await self.fetch(endpoint: endpoint, withParameters: parameters)
    }
    
    public func fetch(endpoint: Endpoint, withParameters parameter: NetworkRequest) async throws -> NetworkResponse {
        guard let request = parameter.makeURLRequest(for: endpoint) else {
            throw NetworkError.malformedRequest
        }
        
        let response = try await self.processRequest(request)
        
        return response
    }
    
    private func processRequest(_ request: URLRequest) async throws -> NetworkResponse {
        let (data, response) = try await self.httpSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badRequest
        }
        
        let apiResponse = try processResponse(httpResponse, data: data)
        
        return apiResponse
    }
        
    private func processResponse(_ httpResponse: HTTPURLResponse, data: Data) throws -> NetworkResponse {
        switch httpResponse.statusCode {
            case 400:
                throw NetworkError.badRequest
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 500:
                throw NetworkError.internalError
            case 503:
                throw NetworkError.serviceUnavailable
            default:
                let apiResponse = NetworkResponse(withCode: httpResponse.statusCode,
                                              results: data,
                                              headers: httpResponse.allHeaderFields)
                
                return apiResponse
        }
    }
}
