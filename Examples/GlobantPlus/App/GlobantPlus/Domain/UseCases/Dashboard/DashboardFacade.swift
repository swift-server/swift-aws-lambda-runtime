//
//  DashboardFacade.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation

final class DashboardFacade {
    private let trendingShowListUseCase: TrendingShowListUseCase
    private let trendingMovieListUseCase: TrendingMovieListUseCase
    private let popularDocumentaryListUseCase: PopularDocumentaryListUseCase
    
    init() {
        self.trendingShowListUseCase = DefaultTrendingShowListUseCase()
        self.trendingMovieListUseCase = DefaultTrendingMovieListUseCase()
        self.popularDocumentaryListUseCase = DefaultPopularDocumentaryListUseCase()
    }
    
    func fetchTrendingShows() async throws -> [TrendingItem] {
        return try await self.trendingShowListUseCase.fetchTrendingShows()
    }
    
    func fetchTrendingMovies() async throws -> [TrendingItem] {
        return try await self.trendingMovieListUseCase.fetchTrendingMovies()
    }
    
    func fetchPopularDocumentaries() async throws -> [TrendingItem] {
        return try await self.popularDocumentaryListUseCase.fetchPopularDocumentaries()
    }
}
