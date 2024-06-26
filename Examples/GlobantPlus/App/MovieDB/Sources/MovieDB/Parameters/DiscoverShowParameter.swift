//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 9/1/23.
//

import Foundation
import Resty

enum DiscoverShowParameter {
    case status(value: ShowStatus)
    case kind(value: ShowKind)
    case runtime(greaterThan: Bool, time: Int)
}

extension DiscoverShowParameter: QueryParameter {
    var queryItem: URLQueryItem {
        switch self {
            case .status(let value):
                return URLQueryItem(name: "with_status", value: "\(value.rawValue)")
            case .kind(let value):
                return URLQueryItem(name: "with_type", value: "\(value.rawValue)")
            case .runtime(let greaterThan, let time):
                let key = "with_runtime." + (greaterThan ? "gte" : "lte")
                return URLQueryItem(name: key, value: "\(time)")
        }
    }
}
