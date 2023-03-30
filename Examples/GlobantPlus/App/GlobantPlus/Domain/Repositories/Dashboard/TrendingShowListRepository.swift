//
//  TrendingShowListRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation

protocol TrendingShowListRepository {
    func fetchTrendingShows() async throws -> [TrendingItem]
}
