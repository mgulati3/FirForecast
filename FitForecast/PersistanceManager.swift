//
//  PersistenceManager.swift
//  FitForecast
//
//  Created by Manan Gulati on 20/04/25.
//

import Foundation
import CoreData

class PersistenceManager {
    static let shared = PersistenceManager()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "FitForecast")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Save changes if there are any
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
