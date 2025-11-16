//
//  VideoCullingApp.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData

@main
struct VideoCullingApp: App {
    // 1. Initialize the Core Data persistence controller
    let persistenceController = PersistenceController.shared
    @State private var showPreferences = false

    init() {
        // Clear all video assets on app launch
        clearAllVideoAssets()
    }

    var body: some Scene {
        WindowGroup {
            // 2. Inject the main context into the SwiftUI environment
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    showPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Preferences window
        Window("Preferences", id: "preferences") {
            PreferencesView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .keyboardShortcut(",", modifiers: .command)
    }

    private func clearAllVideoAssets() {
        let context = persistenceController.container.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ManagedVideoAsset")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear video assets on launch: \(error)")
        }
    }
}
