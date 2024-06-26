import XCTest
@testable import MovieDB

final class MovieDBTests: XCTestCase {
    #warning("Copy your MovieDB API here 👇")
    private let client = MovieDB(apiKey: "")
    
    func testTrendingMovies() async {
        do {
            let movies = try await client.trendingMovies()
            print(movies)
            XCTAssertFalse(movies.isEmpty)
            XCTAssertEqual(movies.count, 20)
        } catch let error {
            print("🚨 \(error)")
            XCTFail(error.localizedDescription)
        }
    }
    
    func testTrendingShows() async {
        do {
            let shows = try await client.trendingShows()
            print(shows)
            XCTAssertFalse(shows.isEmpty)
            XCTAssertEqual(shows.count, 20)
        } catch let error {
            print("🚨 \(error)")
            XCTFail(error.localizedDescription)
        }
    }
}
