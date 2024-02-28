//
//  DefaultDashboardUseCase.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

final class DefaultTrendingShowListUseCase: TrendingShowListUseCase {
    let trendingShowListRepository: DashboardRepository = TMDBDashboardRepository()
    
    func fetchTrendingShows() async throws -> [TrendingItem] {
        return try await trendingShowListRepository.fetchTrendingShows()
    }
}
