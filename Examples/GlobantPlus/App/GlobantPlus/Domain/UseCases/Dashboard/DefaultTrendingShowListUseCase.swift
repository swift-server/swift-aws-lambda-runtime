//
//  DefaultDashboardUseCase.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

final class DefaultTrendingShowListUseCase: TrendingShowListUseCase {
    let trendingShowListRepository: TrendingShowListRepository = TMDBTrendingShowListRepository()
    
    func fetchTrendingShows() async throws -> [TrendingItem] {
        return try await trendingShowListRepository.fetchTrendingShows()
    }
}
