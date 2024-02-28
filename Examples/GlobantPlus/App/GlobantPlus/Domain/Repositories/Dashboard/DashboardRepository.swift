//
//  DashboardRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation

protocol DashboardRepository {
	func fetchTrendingShows() async throws -> [TrendingItem]
	func fetchTrendingMovies() async throws -> [TrendingItem]
    func fetchPopularDocumentaries() async throws -> [TrendingItem]
}
