//
//  TMDBDashboardRepository.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation
import MovieDB

final class TMDBTrendingMovieListRepository: TrendingMovieListRepository {
    let apiClient: MovieDB
    
    init() {
        self.apiClient = MovieDB(token: ApplicationEnvironment.shared.apiToken)
    }
    
    func fetchTrendingMovies() async throws -> [TrendingItem] {
        let apiMovies = try await apiClient.trendingMovies()
        
        let trendingMovies = apiMovies.map({ apiMovie in
            var trendingMovie = TrendingItem(titled: apiMovie.title, ofType: .movie, withIdentifier: apiMovie.id)
            
            trendingMovie.backdropPath = apiClient.makeBackdropUriFrom(path: apiMovie.backdropPath, ofSize: .regular)
            trendingMovie.posterPath = apiClient.makePosterUriFrom(path: apiMovie.posterPath, ofSize: .regular)
            
            trendingMovie.popularity = apiMovie.popularity
            trendingMovie.voteCount = apiMovie.voteCount
            trendingMovie.voteAverage = apiMovie.voteAverage
            
            trendingMovie.isAdultContent = apiMovie.isAdultContent
            trendingMovie.overview = apiMovie.overview
            
            return trendingMovie
        })
        
        return trendingMovies
    }
}
