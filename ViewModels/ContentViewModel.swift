//
//  ContentViewModel.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData

enum NamingConvention: String, CaseIterable, Identifiable {
    case none = "None"
    case datePrefix = "YYYYMMDD-[Original Name]"
    case dateSuffix = "[Original Name]-YYYYMMDD"
    case dateTimePrefix = "YYYYMMDD-HHMMSS-[Original Name]"

    var id: String { self.rawValue }
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var loadingStatus = "Idle"
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var testMode = false
    @Published var inputFolderURL: URL?
    @Published var outputFolderURL: URL?
    @Published var selectedNamingConvention: NamingConvention = .none

    // Progress tracking
    @Published var processingProgress: Double = 0.0
    @Published var currentProcessingFile: String = ""
    @Published var totalFilesToProcess: Int = 0
    @Published var currentFileIndex: Int = 0
    @Published var showProcessingModal: Bool = false

    private var viewContext: NSManagedObjectContext

    // Services
    private let scannerService: FileScannerService
    private let processingService: ProcessingService

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.scannerService = FileScannerService(context: context)
        self.processingService = ProcessingService(context: context)
    }
    
    func closeCurrentFolder() {
        Task {
            // Set loading state to prevent UI updates
            await MainActor.run {
                self.isLoading = true
                self.loadingStatus = "Closing folder..."
            }

            // Clear all video assets from database
            do {
                try await viewContext.perform {
                    let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
                    fetchRequest.includesPropertyValues = false

                    let allAssets = try self.viewContext.fetch(fetchRequest)
                    for asset in allAssets {
                        self.viewContext.delete(asset)
                    }
                    try self.viewContext.save()
                }
            } catch {
                await MainActor.run {
                    self.showErrorMessage("Failed to close folder: \(error.localizedDescription)")
                }
            }

            // Small delay to ensure Core Data notifications are processed
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Clear folder URLs on main thread
            await MainActor.run {
                self.inputFolderURL = nil
                self.outputFolderURL = nil
                self.isLoading = false
                self.loadingStatus = "Folder closed. Select a new folder to begin."
            }
        }
    }

    func selectInputFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a folder containing video files"
        openPanel.prompt = "Select Folder"

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else {
                showErrorMessage("No folder was selected")
                return
            }

            // Verify we have read access
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                showErrorMessage("Cannot read from the selected folder. Please check permissions.")
                return
            }

            // Set the input folder
            self.inputFolderURL = url

            // Set default output folder based on test mode
            updateOutputFolder()

            // Run scanning on a background thread
            Task {
                self.isLoading = true
                self.loadingStatus = "Scanning for videos..."
                self.errorMessage = nil

                await scannerService.scan(
                    folderURL: url,
                    statusUpdate: { status in
                        // Send status updates to the main thread
                        Task { @MainActor in self.loadingStatus = status }
                    }
                )

                self.isLoading = false
                self.loadingStatus = "Idle"
            }
        }
    }

    func selectOutputFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select output folder for processed videos"
        openPanel.prompt = "Select Folder"

        if openPanel.runModal() == .OK {
            self.outputFolderURL = openPanel.url
        }
    }

    func updateOutputFolder() {
        guard let inputURL = inputFolderURL else { return }

        if testMode {
            // In test mode, always use Culled subfolder unless user manually selected different output
            // Reset to Culled subfolder when switching to test mode
            outputFolderURL = inputURL.appendingPathComponent("Culled", isDirectory: true)
        } else {
            // In normal mode, use user-selected output folder or nil for in-place processing
            // If no output folder selected, set to nil (process in-place)
            if outputFolderURL == inputURL.appendingPathComponent("Culled", isDirectory: true) {
                // Was using Culled subfolder from test mode, reset to nil for in-place
                outputFolderURL = nil
            }
            // Otherwise keep user's manually selected output folder
        }
    }
    
    func applyChanges() {
        Task {
            self.isLoading = true
            self.showProcessingModal = true
            self.errorMessage = nil
            self.processingProgress = 0.0
            self.currentProcessingFile = ""
            self.currentFileIndex = 0
            self.totalFilesToProcess = 0

            await processingService.processChanges(
                testMode: testMode,
                outputFolderURL: outputFolderURL,
                statusUpdate: { status in
                    Task { @MainActor in self.loadingStatus = status }
                },
                progressUpdate: { current, total, filename in
                    Task { @MainActor in
                        self.currentFileIndex = current
                        self.totalFilesToProcess = total
                        self.currentProcessingFile = filename
                        self.processingProgress = total > 0 ? Double(current) / Double(total) : 0.0
                    }
                }
            )

            if testMode {
                self.loadingStatus = "Test export complete. Check output folder."
            } else {
                self.loadingStatus = "Processing complete."
            }

            // Clear status after a delay
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                self.loadingStatus = "Idle"
                self.processingProgress = 0.0
                self.currentProcessingFile = ""
                self.currentFileIndex = 0
                self.totalFilesToProcess = 0
                self.showProcessingModal = false
            }

            self.isLoading = false
        }
    }

    private func showErrorMessage(_ message: String) {
        self.errorMessage = message
        self.showError = true
        print("Error: \(message)")
    }

    // MARK: - Global LUT Application

    func applyGlobalLUT(_ lut: LUT?) {
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

        do {
            let allAssets = try viewContext.fetch(fetchRequest)
            for asset in allAssets {
                asset.selectedLUTId = lut?.id.uuidString ?? ""
            }
            try viewContext.save()
        } catch {
            showErrorMessage("Failed to apply global LUT: \(error.localizedDescription)")
        }
    }

    // MARK: - Naming Convention Application

    func applyNamingConvention(_ convention: NamingConvention) {
        guard convention != .none else {
            // Clear all newFileName fields
            let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
            do {
                let allAssets = try viewContext.fetch(fetchRequest)
                for asset in allAssets {
                    asset.newFileName = ""
                }
                try viewContext.save()
            } catch {
                showErrorMessage("Failed to clear naming convention: \(error.localizedDescription)")
            }
            return
        }

        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

        do {
            let allAssets = try viewContext.fetch(fetchRequest)
            for asset in allAssets {
                let newName = generateFileName(for: asset, using: convention)
                asset.newFileName = newName
            }
            try viewContext.save()
        } catch {
            showErrorMessage("Failed to apply naming convention: \(error.localizedDescription)")
        }
    }

    private func generateFileName(for asset: ManagedVideoAsset, using convention: NamingConvention) -> String {
        // Get original filename without extension
        let currentName = asset.fileName ?? "Untitled"
        let nameWithoutExtension = (currentName as NSString).deletingPathExtension

        // Get the earliest date (creation or modification)
        let creationDate = asset.creationDate
        let modificationDate = asset.lastEditDate
        var earliestDate = creationDate ?? modificationDate ?? Date()
        if let creation = creationDate, let modification = modificationDate {
            earliestDate = min(creation, modification)
        }

        let dateFormatter = DateFormatter()

        switch convention {
        case .none:
            return ""

        case .datePrefix:
            // YYYYMMDD-[Original Name]
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateString = dateFormatter.string(from: earliestDate)
            return "\(dateString)-\(nameWithoutExtension)"

        case .dateSuffix:
            // [Original Name]-YYYYMMDD
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateString = dateFormatter.string(from: earliestDate)
            return "\(nameWithoutExtension)-\(dateString)"

        case .dateTimePrefix:
            // YYYYMMDD-HHMMSS-[Original Name]
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let dateTimeString = dateFormatter.string(from: earliestDate)
            return "\(dateTimeString)-\(nameWithoutExtension)"
        }
    }
}
