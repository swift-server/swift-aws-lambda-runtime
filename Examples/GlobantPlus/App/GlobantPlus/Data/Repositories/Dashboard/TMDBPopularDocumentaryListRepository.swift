//
//  TMDBPopularDocumentaryListRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation
import MovieDB

final class TMDBPopularDocumentaryListRepository: PopularDocumentaryListRepository {
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
}
