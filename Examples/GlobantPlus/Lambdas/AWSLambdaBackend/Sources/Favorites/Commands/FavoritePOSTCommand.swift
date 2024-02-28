//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

final class FavoritePOSTCommand: FavoriteCommand {
    private let insertRepository: InsertRepository
    private let favoriteParameter: Favorite
    
    init(parameter: Favorite, repository: InsertRepository) {
        self.favoriteParameter = parameter
        self.insertRepository = repository
    }
    
    func execute() throws {
        try insertRepository.insert(self.favoriteParameter)
    }
}
