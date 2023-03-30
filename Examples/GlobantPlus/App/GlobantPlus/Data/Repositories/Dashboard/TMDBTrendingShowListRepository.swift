//
//  TMDBTrendingShowListRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation
import MovieDB

final class TMDBTrendingShowListRepository: TrendingShowListRepository {
    let apiClient: MovieDB
    
    init() {
        self.apiClient = MovieDB(token: ApplicationEnvironment.shared.apiToken)
    }
    
    func fetchTrendingShows() async throws -> [TrendingItem] {
        async let apiShows = apiClient.trendingShows()
        async let tvGenres = apiClient.genres(for: .tv)
        
        let trendingShows = try await apiShows.map({ apiShow in
            var trendingShow = TrendingItem(titled: apiShow.title, ofType: .tv, withIdentifier: apiShow.id)
            
            trendingShow.backdropPath = apiClient.makeBackdropUriFrom(path: apiShow.backdropPath, ofSize: .regular)
            trendingShow.posterPath = apiClient.makePosterUriFrom(path: apiShow.posterPath, ofSize: .regular)
            
            trendingShow.popularity = apiShow.popularity
            trendingShow.voteCount = apiShow.voteCount
            trendingShow.voteAverage = apiShow.voteAverage
            
            trendingShow.isAdultContent = apiShow.isAdultContent
            trendingShow.overview = apiShow.overview
            
            return trendingShow
        })
        
        return trendingShows
    }
}
