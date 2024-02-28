//
//  TMDBPopularDocumentaryListRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation
import MovieDB

final class TMDBDashboardRepository: DashboardRepository {
    let apiClient: MovieDB
    
    init() {
        self.apiClient = MovieDB(token: ApplicationEnvironment.shared.apiToken)
    }
    
    func fetchPopularDocumentaries() async throws -> [TrendingItem] {
        let apiDocumentaries = try await apiClient.discoverDocumentaries(sortedBy: .popularity)
        
        let trendingDocumentaries = apiDocumentaries.map({ apiDocumentary in
            var trendingDocumentary = TrendingItem(titled: apiDocumentary.title, ofType: .tv, withIdentifier: apiDocumentary.id)
            
            trendingDocumentary.backdropPath = apiClient.makeBackdropUriFrom(path: apiDocumentary.backdropPath, ofSize: .regular)
            trendingDocumentary.posterPath = apiClient.makePosterUriFrom(path: apiDocumentary.posterPath, ofSize: .regular)
            
            trendingDocumentary.popularity = apiDocumentary.popularity
            trendingDocumentary.voteCount = apiDocumentary.voteCount
            trendingDocumentary.voteAverage = apiDocumentary.voteAverage
            trendingDocumentary.overview = apiDocumentary.overview
            
            return trendingDocumentary
        })
        
        return trendingDocumentaries
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
