//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

public enum GenreSource {
    case movie
    case tv
}

extension GenreSource: CustomStringConvertible {
    public var description: String {
        switch self {
            case .movie:
                return "movie"
            case .tv:
                return "tv"
        }
    }
}
