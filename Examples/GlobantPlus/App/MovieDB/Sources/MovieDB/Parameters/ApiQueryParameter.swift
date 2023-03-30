//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation
import Resty

enum ApiQueryParameter {
    case apiKey(value: String)
    case language(code: String)
    case page(value: Int)
    case search(term: String)
}

extension ApiQueryParameter: QueryParameter {
    var queryItem: URLQueryItem {
        switch self {
            case .apiKey(let value):
                return URLQueryItem(name: "api_key", value: value)
            case .language(let code):
                return URLQueryItem(name: "language", value: code)
            case .page(let value):
                return URLQueryItem(name: "page", value: String(value))
            case .search(let term):
                return URLQueryItem(name: "query", value: term)
        }
    }
    
    
}
