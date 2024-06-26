//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

final class FavoriteDELETECommand: FavoriteCommand {
    private let deleteRepository: DeleteRepository
    private let favoriteParameter: Favorite
    
    init(parameter: Favorite, repository: DeleteRepository) {
        self.favoriteParameter = parameter
        self.deleteRepository = repository
    }
    
    func execute() throws {
        try deleteRepository.delete(self.favoriteParameter)
    }
}
