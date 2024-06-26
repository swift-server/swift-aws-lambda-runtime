import Foundation

protocol TrendingShowListUseCase {
    func fetchTrendingShows() async throws -> [TrendingItem]
}
