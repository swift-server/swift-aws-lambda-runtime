//
//  CoreDataInsertFavoriteRepository.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation
import CoreData

final class CoreDataInsertFavoriteRepository: InsertFavoriteRepository {
    func insert(showId: Int) {
        guard let container = CoreDataStorage.defaults.storeContainer else {
            return
        }
        
        let newFavorite = NSEntityDescription.insertNewObject(forEntityName: PCDFavorite.entityName, into: container.viewContext) as! PCDFavorite
        newFavorite.showId = Int32(showId)
        
        CoreDataStorage.defaults.saveContext()
    }
}
