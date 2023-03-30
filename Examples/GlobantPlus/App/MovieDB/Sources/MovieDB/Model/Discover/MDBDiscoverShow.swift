//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 10/1/23.
//

import Foundation

public struct MDBDiscoverShow: Codable, Identifiable {
    public private(set) var id: Int
    public private(set) var title: String
    public private(set) var originalTitle: String
    public private(set) var originalLanguage: String
    public private(set) var originCountries: [String]
    public private(set) var overview: String
    
    public private(set) var genreIds: [Int]
    
    public private(set) var backdropPath: String?
    public private(set) var posterPath: String?
    
    public private(set) var voteAverage: Double
    public private(set) var voteCount: Int
    public private(set) var popularity: Double
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title = "name"
        case originalTitle = "original_name"
        case originalLanguage = "original_language"
        case originCountries = "origin_country"
        case overview
        case genreIds = "genre_ids"
        case backdropPath = "backdrop_path"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity = "popularity"
    }
}
