//
//  DefaultFavoriteUseCase.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation

final class DefaultFavoriteUseCase: FavoriteUseCase {  
    private let favoriteRepository: FavoriteRepository = CoreDataFavoriteRepository()
	private let favoriteTrainingRepository: FavoriteTrainingRepository = AmazonFavoriteTrainingRepository()
    
    func setFavorite(to newState: Bool, for show: ShowID) throws {
        if newState {
			favoriteRepository.insert(showId: show)
            
            Task(priority: .background) {
                try? await favoriteTrainingRepository.post(mediaID: show, forUser: "Adolfo")
            }
        } else {
            try favoriteRepository.delete(showId: show)
            
            Task(priority: .background) {
                try? await favoriteTrainingRepository.delete(mediaID: show, forUser: "Adolfo")
            }
        }
    }
}
