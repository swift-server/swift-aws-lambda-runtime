//
//  AmazonFavoriteTrainningRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation
import Resty

final class AmazonFavoriteTrainingPOSTRepository: AmazonFavoriteTrainingBaseRepository, FavoriteTrainingPOSTRepository {
    func post(mediaID: Int, forUser userID: String) async throws {
        try await super.process(mediaID: mediaID, forUser: userID, httpMethod: .post)
    }
}
