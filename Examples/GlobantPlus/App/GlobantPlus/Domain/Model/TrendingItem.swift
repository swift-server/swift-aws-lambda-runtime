//
//  TrendingItem.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

struct TrendingItem {
    enum Media {
        case tv
        case movie
    }
    
    var id: Int
    var title: String
    var tagline = ""
    var media: TrendingItem.Media
    
    var originalTitle = ""
    var originalLanguage = ""
    var originCountries = [String]()
    var overview = ""
    
    var genres = [String]()
    
    var isAdultContent = false
    
    var backdropPath: String?
    var posterPath: String?
    
    var voteAverage = 0.0
    var voteCount = 0
    var popularity = 0.0
    
    init(titled title: String, ofType media: Media, withIdentifier id: Int) {
        self.id = id
        self.title = title
        self.media = media
    }
}
