//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation

public enum MediaKind {
    case all
    case movie
    case tv
    case person
}

extension MediaKind: CustomStringConvertible {
    public var description: String {
        switch self {
            case .all:
                return "all"
            case .movie:
                return "movie"
            case .tv:
                return "tv"
            case .person:
                return "person"
        }
    }
}
