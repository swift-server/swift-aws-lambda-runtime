//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 9/1/23.
//

import Foundation
import Resty

public extension MovieDB {
    func discoverMovies(sortedBy field: SortField) async throws -> [MDBDiscoverMovie] {
        let popularParameters = [
            DiscoverParameter.sort(by: field, ascendent: false)
        ]
        
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.discover(kind: .movie), withParameters: popularParameters)
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let discoveredMovies = try jsonDecoder.decode(PaginatedResult<MDBDiscoverMovie>.self, from: data)
        
        return discoveredMovies.results
    }
    
    func discoverShows(sortedBy field: SortField) async throws -> [MDBDiscoverShow] {
        let popularParameters = [
            DiscoverParameter.sort(by: field, ascendent: false)
        ]
        
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.discover(kind: .tv), withParameters: popularParameters)
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let discoveredShows = try jsonDecoder.decode(PaginatedResult<MDBDiscoverShow>.self, from: data)
        
        return discoveredShows.results
    }
    
    func discoverDocumentaries(sortedBy field: SortField) async throws  -> [MDBDiscoverShow] {
        let discoverParameters: [QueryParameter] = [
            DiscoverParameter.sort(by: field, ascendent: false),
            DiscoverShowParameter.kind(value: .documentary)
        ]
        
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.discover(kind: .tv), withParameters: discoverParameters)
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let discoveredShows = try jsonDecoder.decode(PaginatedResult<MDBDiscoverShow>.self, from: data)
        
        return discoveredShows.results
    }
    
    func upcomingMovieReleases(from startingDate: Date = Date()) async throws -> [MDBDiscoverMovie] {
        let popularParameters = [
            DiscoverParameter.sort(by: .primaryReleaseDate, ascendent: false),
            DiscoverParameter.primaryReleaseDate(date: startingDate, greaterThanThisDate: true)
        ]
        
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.discover(kind: .movie), withParameters: popularParameters)
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let discoveredMovies = try jsonDecoder.decode(PaginatedResult<MDBDiscoverMovie>.self, from: data)
        
        return discoveredMovies.results
    }
    
    func upcomingShowReleases(from startingDate: Date = Date()) async throws -> [MDBDiscoverShow] {
        let popularParameters = [
            DiscoverParameter.sort(by: .primaryReleaseDate, ascendent: false),
            DiscoverParameter.primaryReleaseDate(date: startingDate, greaterThanThisDate: true)
        ]
        
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.discover(kind: .tv), withParameters: popularParameters)
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        
        let discoveredShows = try jsonDecoder.decode(PaginatedResult<MDBDiscoverShow>.self, from: data)
        
        return discoveredShows.results
    }
}
