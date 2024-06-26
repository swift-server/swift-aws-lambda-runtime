//
//  PCDFavorite+CoreDataProperties.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 10/3/23.
//
//

import Foundation
import CoreData


extension PCDFavorite {
    @NSManaged public var showId: Int32
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PCDFavorite> {
        return NSFetchRequest<PCDFavorite>(entityName: "PCDFavorite")
    }
}

extension PCDFavorite : Identifiable {
    public var id: Int {
        return Int(self.showId)
    }
}
