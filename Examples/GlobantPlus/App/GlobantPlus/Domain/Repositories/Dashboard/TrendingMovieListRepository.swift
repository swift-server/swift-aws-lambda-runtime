import Foundation

protocol TrendingMovieListRepository {
    func fetchTrendingMovies() async throws -> [TrendingItem]
}
