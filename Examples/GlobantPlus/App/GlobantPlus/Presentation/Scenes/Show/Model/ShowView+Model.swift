//
//  ShowView+Model.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation

extension ShowView {
    struct Model: Identifiable {
        var id = 0
        var title = ""
        var tagline = ""
        var overview = ""
        var genres = ""
        
        var episodeCount = 0
        var seasonCount = 0
        var episodeRuntime = 0
        var voteAverage = 0.0
        
        var backdropPath: String?
        
        var isFavorite = false
    }
}
