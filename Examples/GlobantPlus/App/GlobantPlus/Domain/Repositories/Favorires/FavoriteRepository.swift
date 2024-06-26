//
//  DeleteFavoriteRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation

protocol FavoriteRepository {
	func existFavoriteFor(showID: ShowID) throws -> Bool
	
	func fetchFavoriteList() throws -> [ShowID]
	func fetchFavoriteFor(showID: ShowID) throws -> ShowID
	
	func insert(showId: ShowID)
	
    func delete(showId: ShowID) throws
}
