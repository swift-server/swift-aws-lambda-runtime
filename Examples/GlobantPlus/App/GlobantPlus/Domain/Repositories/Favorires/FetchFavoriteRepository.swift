//
//  FetchFavoriteRepository.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation

protocol FetchFavoriteRepository {
    func fetchFavoriteList() throws -> [ShowID]
    func fetchFavoriteFor(showID: ShowID) throws -> ShowID
    func existFavoriteFor(showID: ShowID) throws -> Bool
}
