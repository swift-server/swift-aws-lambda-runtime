//
//  AmazonFavoriteEndpoint.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation
import Resty

enum AmazonFavoriteEndpoint {
    case favorite
}

extension AmazonFavoriteEndpoint {
    var baseURL: String {
        return ApplicationEnvironment.shared.awsAPIGatewayURL
    }
}

extension AmazonFavoriteEndpoint: Endpoint {
    var path: String {
        switch self {
            case .favorite:
                return "\(baseURL)/favorites"
        }
    }
}
