//
//  DeviceStorage.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 09/09/2022
//

import CoreData
import Foundation

final class CoreDataStorage {
    
    /// Singleton
    static let defaults = CoreDataStorage()

    var storeContainer: NSPersistentCloudKitContainer!

    /// Contexto del contenedor de datos
    public var managedObjectContext: NSManagedObjectContext {
        return self.storeContainer.viewContext
    }

    ///
    private lazy var applicationDataPath: URL = {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = url.appendingPathComponent(StorageSettings.databaseName)

        return url
    }()
    
    //
    // MARK: - Inicializamos
    //

    private init() {
        self.prepareStack()
    }

    //
    // MARK: - Core Data stack
    //

    private func prepareStack() {
        let persistentDescription = NSPersistentStoreDescription(url: self.applicationDataPath)

        persistentDescription.type = NSSQLiteStoreType
        persistentDescription.shouldInferMappingModelAutomatically = true
        persistentDescription.shouldMigrateStoreAutomatically = true

        let container = NSPersistentCloudKitContainer(name: StorageSettings.modelName)
        container.persistentStoreDescriptions = [ persistentDescription ]

        container.loadPersistentStores(completionHandler: {  (storeDescription: NSPersistentStoreDescription, error: Error?) -> Void in
            if let error = error {
                let message = "!!! Problema al cargar los stores de Core Data.\n\(error.localizedDescription), \(String(describing: error._userInfo))"
                fatalError(message)
            }
        })

        self.storeContainer = container
    }

    //
    // MARK: - Core Data Operations
    //
    
    func saveContext () {
        guard let container = self.storeContainer, container.viewContext.hasChanges else {
            return 
        }
        
        do {
            // Guardamos en Core Data...
            try container.viewContext.save()
        } catch {
            print("err @ CORE DATA CONTEXT saveContext()")
        }
    }
    
    /**
 
    */
    func resetContext() {
        guard let container = self.storeContainer else {
            return
        }
        
        container.viewContext.performAndWait {
            container.viewContext.reset()
        }
    }
}
