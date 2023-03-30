//
//  FavoriteTrainingDELETERepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation

protocol FavoriteTrainingDELETERepository {
    func delete(mediaID: Int, forUser userID: String) async throws
}
