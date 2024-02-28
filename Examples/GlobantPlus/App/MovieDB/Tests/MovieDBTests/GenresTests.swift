import XCTest
@testable import MovieDB

final class GenresTests: XCTestCase {
    #warning("Copy your MovieDB API here 👇")
    private let client = MovieDB(apiKey: "")
    
    func testMovieGenres() async {
        do {
            let genres = try await client.genres(for: .movie)
            print(genres)
            
            XCTAssertFalse(genres.isEmpty)
        } catch let error {
            print(error)
            XCTFail(error.localizedDescription)
        }
    }
    
    func testTVGenres() async {
        do {
            let genres = try await client.genres(for: .tv)
            print(genres)
            
            XCTAssertFalse(genres.isEmpty)
        } catch let error {
            print(error)
            XCTFail(error.localizedDescription)
        }
    }
}
