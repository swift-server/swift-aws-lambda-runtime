//
//  AmazonFavoriteTrainningDELETERepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation
import Resty

final class AmazonFavoriteTrainingDELETERepository: AmazonFavoriteTrainingBaseRepository, FavoriteTrainingDELETERepository {
    func delete(mediaID: Int, forUser userID: String) async throws {
        try await super.process(mediaID: mediaID, forUser: userID, httpMethod: .delete)
    }
}
