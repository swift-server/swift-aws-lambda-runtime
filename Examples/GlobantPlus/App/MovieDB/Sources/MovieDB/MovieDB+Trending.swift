//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation
import Resty

public extension MovieDB {
    func trendingMovies() async throws -> [MDBTrendingMovie] {
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.trending(kind: .movie, period: .week))
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let movies = try jsonDecoder.decode(PaginatedResult<MDBTrendingMovie>.self, from: data)
        
        return movies.results 
    }
    
    func trendingShows() async throws -> [MDBTrendingShow] {
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.trending(kind: .tv, period: .day))
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let movies = try jsonDecoder.decode(PaginatedResult<MDBTrendingShow>.self, from: data)
        
        return movies.results
    }
}
