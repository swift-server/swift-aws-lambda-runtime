//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 10/1/23.
//

import Foundation

enum DiscoverMedia {
    case movie
    case tv
}

extension DiscoverMedia: CustomStringConvertible {
    public var description: String {
        switch self {
            case .movie:
                return "movie"
            case .tv:
                return "tv"
        }
    }
}
