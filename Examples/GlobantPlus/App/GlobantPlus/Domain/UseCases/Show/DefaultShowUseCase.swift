//
//  DefaultShowUseCase.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation

final class DefaultShowUseCase: ShowUseCase {
    private(set) var showRepository: ShowRepository = TMDBShowRepository()
    private(set) var fetchFavorite: FetchFavoriteRepository = CoreDataFetchFavoriteRepository()
    
    /*
    init(repository: ShowRepository) {
        self.showRepository = repository
    }
    */
    func fetchShow(identifiedAs showId: Int) async throws -> Show {
        do {
            var show = try await self.showRepository.fetchShow(identifiedAs: showId)
            show.isFavorite = try fetchFavorite.existFavoriteFor(showID: showId)
            
            return show
        } catch let error {
            print("🚨 No podemos recuperar todos los datos de la serie. \(error)")
            throw GlobantPlusError.emptyResults
        }
    }
}
