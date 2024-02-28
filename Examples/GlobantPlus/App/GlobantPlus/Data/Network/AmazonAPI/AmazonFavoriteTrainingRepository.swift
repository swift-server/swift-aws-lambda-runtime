//
//  AmazonFavoriteTrainingRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation
import Resty

final class AmazonFavoriteTrainingRepository: AmazonFavoriteTrainingBaseRepository, FavoriteTrainingRepository {
	func post(mediaID: Int, forUser userID: String) async throws {
		try await super.process(mediaID: mediaID, forUser: userID, httpMethod: .post)
	}
	
	func delete(mediaID: Int, forUser userID: String) async throws {
        try await super.process(mediaID: mediaID, forUser: userID, httpMethod: .delete)
    }
}
