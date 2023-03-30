//
//  NetworkFavoriteRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 14/3/23.
//

import Foundation

protocol FavoriteTrainingPOSTRepository {
    func post(mediaID: Int, forUser userID: String) async throws
}
