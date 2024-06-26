//
//  TrendingMovieListUseCase.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation

protocol TrendingMovieListUseCase {
    func fetchTrendingMovies() async throws -> [TrendingItem]
}
