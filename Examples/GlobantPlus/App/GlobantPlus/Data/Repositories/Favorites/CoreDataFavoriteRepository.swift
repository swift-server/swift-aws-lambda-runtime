//
//  CoreDataFavoriteRepository.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation
import CoreData

final class CoreDataFavoriteRepository: FavoriteRepository {
	func existFavoriteFor(showID: ShowID) throws -> Bool {
		guard let _ = try? self.fetchFavoriteManagedObjectFor(showID: showID) else {
			return false
		}
		
		return true
	}
	
	func fetchFavoriteManagedObjectFor(showID: Int) throws -> PCDFavorite {
		guard let container = CoreDataStorage.defaults.storeContainer else {
			throw GlobantPlusError.dataSourceFailure
		}
		
		let request: NSFetchRequest<PCDFavorite> = PCDFavorite.fetchRequest()
		request.predicate = NSPredicate(format: "showId = %@", argumentArray: [ showID ])

		
		guard let favorites = try? container.viewContext.fetch(request),
			  let favorite = favorites.first
		else
		{
			throw GlobantPlusError.emptyResults
		}
		
		return favorite
	}
	
	func fetchFavoriteList() throws -> [ShowID]{
		guard let container = CoreDataStorage.defaults.storeContainer else {
			throw GlobantPlusError.dataSourceFailure
		}
		
		let request: NSFetchRequest<PCDFavorite> = PCDFavorite.fetchRequest()
		
		let sortID = NSSortDescriptor(key: "showId", ascending: true)
		
		request.sortDescriptors = [ sortID ]
		
		guard let favorites = try? container.viewContext.fetch(request) else {
			throw GlobantPlusError.emptyResults
		}
		
		let domainFavorites = favorites.compactMap({ Int($0.showId) })
		return domainFavorites
	}
	
	func fetchFavoriteFor(showID: ShowID) throws -> ShowID {
		guard let container = CoreDataStorage.defaults.storeContainer else {
			throw GlobantPlusError.dataSourceFailure
		}
		
		let request: NSFetchRequest<PCDFavorite> = PCDFavorite.fetchRequest()
		request.predicate = NSPredicate(format: "showId = %@", argumentArray: [ showID ])

		
		guard let favorites = try? container.viewContext.fetch(request),
			  let favorite = favorites.first
		else
		{
			throw GlobantPlusError.emptyResults
		}
		
		return ShowID(favorite.showId)
	}
	
	func insert(showId: Int) {
		guard let container = CoreDataStorage.defaults.storeContainer else {
			return
		}
		
		let newFavorite = NSEntityDescription.insertNewObject(forEntityName: PCDFavorite.entityName, into: container.viewContext) as! PCDFavorite
		newFavorite.showId = Int32(showId)
		
		CoreDataStorage.defaults.saveContext()
	}
	
    func delete(showId: Int) throws {
        guard let container = CoreDataStorage.defaults.storeContainer,
              let favorite = try? self.fetchFavoriteManagedObjectFor(showID: showId)
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
