import Foundation

public struct NetworkResponse {
    public private(set) var data: Data?
    public private(set) var headers: [AnyHashable : Any]?
    public private(set) var httpCodeResponse: Int
    
    init(withCode httpCode: Int, results data: Data? = nil, headers: [AnyHashable : Any]? = nil) {
        self.httpCodeResponse = httpCode
        self.data = data
        self.headers = headers
    }
}
