//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 10/1/23.
//

import Foundation

public enum SortField {
    case popularity
    case releaseDate
    case revenue
    case primaryReleaseDate
    case originalTitle
    case voteAverage
    case voteCount
}

extension SortField: CustomStringConvertible {
    public var description: String {
        switch self {
            case .popularity:
                return "popularity"
            case .releaseDate:
                return "release_date"
            case .revenue:
                return "revenue"
            case .primaryReleaseDate:
                return "primary_release_date"
            case .originalTitle:
                return "original_title"
            case .voteAverage:
                return "vote_average"
            case .voteCount:
                return "vote_count"
        }
    }
}
