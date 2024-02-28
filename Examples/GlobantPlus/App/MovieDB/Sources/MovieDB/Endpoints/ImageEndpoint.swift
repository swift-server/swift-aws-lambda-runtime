//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation
import Resty

enum ImageEndpoint {
    case poster(size: PosterSize, path: String)
    case backdrop(size: BackdropSize, path: String)
    case company(size: LogoSize, path: String)
}

extension ImageEndpoint {
    var basePath: String {
        return "https://image.tmdb.org/t/p"
    }
}

extension ImageEndpoint: Endpoint {
    var path: String {
        switch self {
            case .poster(let size, let path):
                return "\(basePath)/\(size)\(path)"
            case .backdrop(let size, let path):
                return "\(basePath)/\(size)\(path)"
            case .company(let size, let path):
                return "\(basePath)/\(size)\(path)"
        }
    }
}
