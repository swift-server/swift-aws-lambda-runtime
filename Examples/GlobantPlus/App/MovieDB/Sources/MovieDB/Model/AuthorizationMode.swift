//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation

public enum AuthorizationMode {
    case apiKey(key: String)
    case header(token: String)
}

extension AuthorizationMode {
    public var value: String {
        switch self {
            case .apiKey(let key):
                return key
            case .header(let token):
                return token
        }
    }
}
