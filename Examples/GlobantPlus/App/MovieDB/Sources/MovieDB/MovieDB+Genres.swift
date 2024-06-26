import Foundation
import Resty

extension MovieDB {
    public func genres(for source: GenreSource) async throws -> [MDBGenre] {
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.genre(source: source))
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let genreList = try jsonDecoder.decode(MDBGenreList.self, from: data)
        
        return genreList.genres
    }
}
