//
//  Show.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation

typealias ShowID = Int

struct Show {
    let id: ShowID
    let title: String
    var tagline = ""
    var originCountries = [String]()
    var overview = ""
    var isInProduction = true
    var currentStatus: String?
    
    var episodeCount = 0
    var seasonCount = 0
    var episodeRuntime = 0
    var voteAverage = 0.0
    
    var genres = [Genre]()
    
    var backdropPath: String?
    
    var isFavorite = false
    
    init(titled title: String, identifiedAs id: ShowID) {
        self.id = id
        self.title = title
    }
}
