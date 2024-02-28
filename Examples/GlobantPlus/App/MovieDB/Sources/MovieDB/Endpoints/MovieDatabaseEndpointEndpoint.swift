//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation
import Resty

enum MovieDatabaseEndpoint {
    case trending(kind: MediaKind, period: TimeWindow)
    case genre(source: GenreSource)
    case discover(kind: DiscoverMedia)
    case show(id: Int)
}

extension MovieDatabaseEndpoint {
    var basePath: String {
        return "https://api.themoviedb.org/3"
    }
}

extension MovieDatabaseEndpoint: Endpoint {
    var path: String {
        switch self {
            case .trending(let kind, let period):
                return "\(basePath)/trending/\(kind.description)/\(period.description)"
            case .genre(let source):
                return "\(basePath)/genre/\(source.description)/list"
            case .discover(let kind):
                return "\(basePath)/discover/\(kind.description)"
            case .show(let id):
                return "\(basePath)/tv/\(id)"
        }
    }
}
