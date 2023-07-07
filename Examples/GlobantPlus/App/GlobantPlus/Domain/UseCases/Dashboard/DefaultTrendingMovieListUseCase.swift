//
//  DefaultTrendingMovieListUseCase.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation

final class DefaultTrendingMovieListUseCase: TrendingMovieListUseCase {
    let trendingMovieListRepository: DashboardRepository = TMDBDashboardRepository()
    
    func fetchTrendingMovies() async throws -> [TrendingItem] {
        return try await trendingMovieListRepository.fetchTrendingMovies()
    }
}
