//
//  DefaultFavoriteUseCase.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation

final class DefaultFavoriteUseCase: FavoriteUseCase {  
    private let insertRepository: InsertFavoriteRepository = CoreDataInsertFavoriteRepository()
    private let deleteRepository: DeleteFavoriteRepository = CoreDataDeleteFavoriteRepository()
    
    private let favoriteTrainingPOST = AmazonFavoriteTrainingPOSTRepository()
    private let favoriteTrainingDELETE = AmazonFavoriteTrainingDELETERepository()
    
    func setFavorite(to newState: Bool, for show: ShowID) throws {
        if newState {
            insertRepository.insert(showId: show)
            
            Task(priority: .background) {
                try? await favoriteTrainingPOST.post(mediaID: show, forUser: "Adolfo")
            }
        } else {
            try deleteRepository.delete(showId: show)
            
            Task(priority: .background) {
                try? await favoriteTrainingDELETE.delete(mediaID: show, forUser: "Adolfo")
            }
        }
    }
}
