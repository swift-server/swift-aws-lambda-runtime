//
//  TMDBShowRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation
import MovieDB

final class TMDBShowRepository: ShowRepository {
    let apiClient: MovieDB
    
    init() {
        self.apiClient = MovieDB(token: ApplicationEnvironment.shared.apiToken)
    }
    
    func fetchShow(identifiedAs showId: Int) async throws -> Show {
        let apiShow = try await apiClient.showDetails(showId: showId)
        
        var show = Show(titled: apiShow.title, identifiedAs: apiShow.id)
        
        show.tagline = apiShow.tagline
        show.overview = apiShow.overview
        show.currentStatus = apiShow.currentStatus
        show.backdropPath = apiClient.makeBackdropUriFrom(path: apiShow.backdropPath, ofSize: .large)
        show.originCountries = apiShow.originCountries
        show.isInProduction = apiShow.isInProduction
        
        show.episodeCount = apiShow.episodeCount
        show.seasonCount = apiShow.seasonCount
        show.episodeRuntime = apiShow.episodesRuntime.average()
        show.voteAverage = apiShow.voteAverage
        
        show.genres = apiShow.genres.map { apiGenre in
            return Genre(id: apiGenre.id, name: apiGenre.name)
        }
        
        return show
    }
}
