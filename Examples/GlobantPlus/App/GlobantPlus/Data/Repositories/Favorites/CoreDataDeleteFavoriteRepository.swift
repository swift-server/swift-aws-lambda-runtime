//
//  CoreDataDeleteFavoriteRepository.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation
import CoreData

final class CoreDataDeleteFavoriteRepository: DeleteFavoriteRepository {
    func delete(showId: Int) throws {
        let fetchRepository = CoreDataFetchFavoriteRepository()
        
        guard let container = CoreDataStorage.defaults.storeContainer,
              let favorite = try? fetchRepository.fetchFavoriteManagedObjectFor(showID: showId)
        else
        {
            throw GlobantPlusError.dataSourceFailure
        }
        
        do {
            container.viewContext.delete(favorite)
            try container.viewContext.save()
        } catch {
            throw GlobantPlusError.dataSourceFailure
        }
    }
}
