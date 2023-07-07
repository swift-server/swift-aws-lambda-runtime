//
//  FavoriteTrainingRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation

protocol FavoriteTrainingRepository {
	func post(mediaID: Int, forUser userID: String) async throws
    func delete(mediaID: Int, forUser userID: String) async throws
}
