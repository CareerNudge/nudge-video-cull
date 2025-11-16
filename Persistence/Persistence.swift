//
//  Persistence.swift
//  VideoCullingApp
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // 1. Make sure this name matches your .xcdatamodeld file
        container = NSPersistentContainer(name: "VideoCullingApp")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error with detailed information
                print("Core Data Error: Failed to load persistent store")
                print("Description: \(error)")
                print("User Info: \(error.userInfo)")

                // In production, you might want to handle this more gracefully
                // For now, we'll crash with a descriptive message
                fatalError("Unresolved Core Data error: \(error.localizedDescription)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Helper function to save context easily
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Core Data Save Error: \(nserror.localizedDescription)")
                print("User Info: \(nserror.userInfo)")

                // Attempt to rollback changes
                context.rollback()

                // In production, you might want to show an alert to the user
                // For now, we'll log and continue
                print("Changes rolled back due to save error")
            }
        }
    }
}
