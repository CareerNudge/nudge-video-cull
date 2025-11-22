//
//  ContentViewModel.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData
import Foundation

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
    @Published var inputFolderURL: URL?
    @Published var outputFolderURL: URL?
    @Published var stagingFolderURL: URL?

    // Progress tracking
    @Published var processingProgress: Double = 0.0
    @Published var currentProcessingFile: String = ""
    @Published var totalFilesToProcess: Int = 0
    @Published var currentFileIndex: Int = 0
    @Published var showProcessingModal: Bool = false

    // Cancellation support
    @Published var isCancelling: Bool = false
    private var processingTask: Task<Void, Never>?

    // Cache for external media checks to prevent repeated disk I/O
    private var externalMediaCache: [String: Bool] = [:]

    // Track if initial app load is complete (prevent auto-scan during app launch)
    private var hasCompletedInitialLoad = false

    // First-time user guidance
    @Published var highlightInputFolderButton: Bool = false
    @Published var highlightOutputFolderButton: Bool = false

    // FCPXML Export
    @Published var processingComplete: Bool = false

    // Multi-selection support
    @Published var selectedAssets: Set<NSManagedObjectID> = []

    // Workflow mode tracking (synced with UserPreferences)
    var workflowMode: UserPreferences.WorkflowModeOption {
        get {
            UserPreferences.shared.workflowMode
        }
        set {
            UserPreferences.shared.workflowMode = newValue
        }
    }

    // Sort order for gallery
    @Published var sortOrder: SortOrder = .oldestFirst {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: "galleryViewSortOrder")
        }
    }

    enum SortOrder: String, CaseIterable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
    }

    // External media staging
    @Published var showExternalMediaAlert: Bool = false
    @Published var pendingFolderURL: URL?
    @Published var isStaging: Bool = false
    @Published var stagingProgress: Double = 0.0
    @Published var stagingStatus: String = ""

    nonisolated private let viewContext: NSManagedObjectContext

    // Services
    private let scannerService: FileScannerService
    private let processingService: ProcessingService
    private let fcpExporter = FCPXMLExporter()

    // Preferences (read from UserPreferences)
    var testMode: Bool {
        UserPreferences.shared.testMode
    }

    var selectedNamingConvention: NamingConvention {
        get {
            NamingConvention(rawValue: UserPreferences.shared.defaultNamingConvention) ?? .none
        }
        set {
            UserPreferences.shared.defaultNamingConvention = newValue.rawValue
        }
    }

    // Persistent folder paths (security-scoped bookmarks)
    private let lastInputFolderKey = "lastInputFolderBookmark"
    private let lastOutputFolderKey = "lastOutputFolderBookmark"
    private let lastStagingFolderKey = "stagingFolderBookmark"

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.scannerService = FileScannerService(context: context)
        self.processingService = ProcessingService(context: context)

        // Load saved sort order preference
        if let savedSortOrder = UserDefaults.standard.string(forKey: "galleryViewSortOrder"),
           let sortOrder = SortOrder(rawValue: savedSortOrder) {
            self.sortOrder = sortOrder
        }

        // Check for UI test mode
        if ProcessInfo.processInfo.environment["TEST_MODE"] == "1" {
            Task { @MainActor in
                print("🧪 TEST_MODE: Detected. Setting up test data and scanning.")
                await self.setupTestMode()
                await self.scanInputFolder() // Automatically scan in test mode
                print("🧪 TEST_MODE: Initial scan triggered.")
            }
        } else {
            // Restore last used folders
            Task { @MainActor in
                self.restoreLastUsedFolders()
            }
        }
    }

    // Auto-load test data for UI testing
    private func setupTestMode() async {
        guard let testInputPath = ProcessInfo.processInfo.environment["TEST_INPUT_PATH"],
              let testOutputPath = ProcessInfo.processInfo.environment["TEST_OUTPUT_PATH"] else {
            print("⚠️ TEST_MODE enabled but TEST_INPUT_PATH or TEST_OUTPUT_PATH not set")
            return
        }

        print("🧪 TEST MODE: Auto-loading test data")
        print("   Input: \(testInputPath)")
        print("   Output: \(testOutputPath)")

        let inputURL = URL(fileURLWithPath: testInputPath)
        let outputURL = URL(fileURLWithPath: testOutputPath)

        self.inputFolderURL = inputURL
        self.outputFolderURL = outputURL

        // Automatically start scanning (same pattern as restoreLastUsedFolders)
        self.isLoading = true
        self.loadingStatus = "Scanning test data..."

        await scannerService.scan(
            folderURL: inputURL,
            statusUpdate: { @Sendable status in
                Task { @MainActor in self.loadingStatus = status }
            },
            progressUpdate: { @Sendable current, total, filename in
                Task { @MainActor in
                    self.currentFileIndex = current
                    self.totalFilesToProcess = total
                    self.currentProcessingFile = filename
                    self.processingProgress = total > 0 ? Double(current) / Double(total) : 0.0
                }
            }
        )

        self.isLoading = false
        self.loadingStatus = "Test data loaded"
        print("🧪 TEST MODE: Scan complete - \(self.totalFilesToProcess) files loaded")
    }

    // MARK: - Workflow Mode Selection

    func setImportMode() {
        workflowMode = .importMode
        // Will require both input and output folders
    }

    func setCullInPlaceMode() {
        workflowMode = .cullInPlace
        // Only requires input folder, output will be nil
    }

    // MARK: - Folder Scanning

    /// Scan the input folder for video files
    func scanInputFolder() async {
        guard let inputURL = inputFolderURL else {
            print("⚠️ No input folder selected")
            return
        }

        self.isLoading = true
        self.loadingStatus = "Scanning..."

        await scannerService.scan(
            folderURL: inputURL,
            statusUpdate: { @Sendable status in
                Task { @MainActor in self.loadingStatus = status }
            },
            progressUpdate: { @Sendable current, total, filename in
                Task { @MainActor in
                    self.currentFileIndex = current
                    self.totalFilesToProcess = total
                    self.currentProcessingFile = filename
                    self.processingProgress = total > 0 ? Double(current) / Double(total) : 0.0
                }
            }
        )

        // Keep loading status active while thumbnails generate and UI stabilizes
        self.loadingStatus = "Loading thumbnails..."
        print("✓ Scan complete - \(self.totalFilesToProcess) files loaded, generating thumbnails...")

        // Wait for all filmstrip thumbnails to complete (with timeout)
        let startTime = Date()
        let maxWaitTime: TimeInterval = 30.0 // 30 second timeout

        while ThumbnailService.shared.pendingFilmstripThumbnails > 0 {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxWaitTime {
                print("⚠️ Thumbnail loading timeout after \(maxWaitTime)s. Remaining: \(ThumbnailService.shared.pendingFilmstripThumbnails)")
                break
            }

            // Update status with progress
            let remaining = ThumbnailService.shared.pendingFilmstripThumbnails
            self.loadingStatus = "Loading thumbnails... (\(remaining) remaining)"

            try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
        }

        self.isLoading = false
        self.loadingStatus = "Ready"
        print("✓ Loading complete - all thumbnails generated")
    }

    // MARK: - Persistent Folder Storage

    /// Save a security-scoped bookmark for a folder URL
    /// Uses DispatchQueue to avoid blocking UI while preventing SwiftUI update loops
    func saveSecurityScopedBookmark(for url: URL, key: String) {
        print("📝 [Bookmark] Saving bookmark for key '\(key)': \(url.path)")

        // Use DispatchQueue.global instead of Task to avoid SwiftUI update loops
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                // Save to UserDefaults (thread-safe operation)
                UserDefaults.standard.set(bookmarkData, forKey: key)

                DispatchQueue.main.async {
                    print("✅ [Bookmark] Successfully saved bookmark for key '\(key)': \(url.path)")
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ [Bookmark] Failed to create bookmark for key '\(key)' at \(url.path): \(error)")
                }
            }
        }
    }

    /// Restore a folder URL from a security-scoped bookmark
    private func restoreSecurityScopedBookmark(key: String) -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("⚠️ Bookmark is stale for key: \(key), will need to re-select folder")
                UserDefaults.standard.removeObject(forKey: key)
                return nil
            }

            // Start accessing the security-scoped resource
            _ = url.startAccessingSecurityScopedResource()

            print("✅ Restored bookmark: \(url.path)")
            return url
        } catch {
            print("❌ Failed to restore bookmark for key \(key): \(error)")
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    /// Restore last used folders on app launch
    private func restoreLastUsedFolders() {
        print("\n🔄 [RESTORE] Restoring last used folders on app launch...")
        let preferences = UserPreferences.shared

        // Restore input folder
        var inputURL: URL?

        print("   [SOURCE] Checking preference: \(preferences.defaultSourceFolder.rawValue)")
        print("   [SOURCE] Custom path: '\(preferences.customSourcePath)'")

        // Check preference setting
        if preferences.defaultSourceFolder == .customPath && !preferences.customSourcePath.isEmpty {
            // Use custom default path
            inputURL = URL(fileURLWithPath: preferences.customSourcePath)
            print("   📁 [SOURCE] Using custom default source: \(preferences.customSourcePath)")
        } else {
            // Use last used folder
            print("   🔍 [SOURCE] Attempting to restore bookmark with key: '\(lastInputFolderKey)'")
            inputURL = restoreSecurityScopedBookmark(key: lastInputFolderKey)
            if inputURL != nil {
                print("   ✅ [SOURCE] Restored last used input folder: \(inputURL!.path)")
            } else {
                print("   ⚠️ [SOURCE] No bookmark found for key: '\(lastInputFolderKey)'")
            }
        }

        if let inputURL = inputURL {
            self.inputFolderURL = inputURL
            print("   ✅ [SOURCE] Set inputFolderURL to: \(inputURL.path)")
            print("   ℹ️ [SOURCE] Scanning deferred until user clicks GO")
        } else {
            print("   ℹ️ [SOURCE] No saved input folder to restore")
        }

        // Restore output folder
        var outputURL: URL?

        print("   [DESTINATION] Checking preference: \(preferences.defaultDestinationFolder.rawValue)")
        print("   [DESTINATION] Custom path: '\(preferences.customDestinationPath)'")

        // Check preference setting
        if preferences.defaultDestinationFolder == .customPath && !preferences.customDestinationPath.isEmpty {
            // Use custom default path
            outputURL = URL(fileURLWithPath: preferences.customDestinationPath)
            print("   📁 [DESTINATION] Using custom default destination: \(preferences.customDestinationPath)")
        } else {
            // Use last used folder
            print("   🔍 [DESTINATION] Attempting to restore bookmark with key: '\(lastOutputFolderKey)'")
            outputURL = restoreSecurityScopedBookmark(key: lastOutputFolderKey)
            if outputURL != nil {
                print("   ✅ [DESTINATION] Restored last used output folder: \(outputURL!.path)")
            } else {
                print("   ⚠️ [DESTINATION] No bookmark found for key: '\(lastOutputFolderKey)'")
            }
        }

        if let outputURL = outputURL {
            self.outputFolderURL = outputURL
            print("   ✅ [DESTINATION] Set outputFolderURL to: \(outputURL.path)")
        } else {
            print("   ℹ️ [DESTINATION] No saved output folder to restore")
        }

        print("🔄 [RESTORE] Folder restoration complete")
        print("   Final inputFolderURL: \(inputFolderURL?.path ?? "nil")")
        print("   Final outputFolderURL: \(outputFolderURL?.path ?? "nil")\n")

        // Mark initial load as complete to allow auto-scanning on subsequent folder selections
        hasCompletedInitialLoad = true
    }

    func closeCurrentFolder() {
        Task {
            // Set loading state to prevent UI updates
            await MainActor.run {
                self.isLoading = true
                self.loadingStatus = "Closing folder..."
            }

            // Clear all video assets from database using batch delete (safer and faster)
            do {
                try await viewContext.perform {
                    // Use NSBatchDeleteRequest for better performance and fewer observer issues
                    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ManagedVideoAsset")
                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    batchDeleteRequest.resultType = .resultTypeObjectIDs

                    // Execute the batch delete
                    let result = try self.viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                    let objectIDArray = result?.result as? [NSManagedObjectID] ?? []

                    // Merge the changes into the context to notify observers
                    let changes = [NSDeletedObjectsKey: objectIDArray]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
                }
            } catch {
                await MainActor.run {
                    self.showErrorMessage("Failed to close folder: \(error.localizedDescription)")
                }
            }

            // Small delay to ensure Core Data notifications are processed
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

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
        // Clear external media cache when selecting new folder
        externalMediaCache.removeAll()

        print("\n📂 [SOURCE FOLDER] Opening source folder selection panel")
        print("   Current inputFolderURL: \(inputFolderURL?.path ?? "nil")")
        print("   Current outputFolderURL: \(outputFolderURL?.path ?? "nil")")

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a folder containing video files"
        openPanel.prompt = "Select Folder"

        // Set initial directory based on user preferences
        let preferences = UserPreferences.shared
        print("   defaultSourceFolder setting: \(preferences.defaultSourceFolder.rawValue)")
        print("   customSourcePath: '\(preferences.customSourcePath)'")

        if preferences.defaultSourceFolder == .customPath && !preferences.customSourcePath.isEmpty {
            let customURL = URL(fileURLWithPath: preferences.customSourcePath)
            openPanel.directoryURL = customURL
            print("   📁 Using custom default source path: \(customURL.path)")
        } else if preferences.defaultSourceFolder == .lastUsed {
            // First check saved path string in preferences
            if !preferences.lastUsedInputPath.isEmpty {
                let lastUsedURL = URL(fileURLWithPath: preferences.lastUsedInputPath)
                openPanel.directoryURL = lastUsedURL
                print("   📁 Using saved last used source path: \(lastUsedURL.path)")
            } else if let lastUsed = inputFolderURL {
                // Fall back to current state if no saved path
                openPanel.directoryURL = lastUsed
                print("   📁 Using current source folder: \(lastUsed.path)")
            }
        } else {
            print("   📁 No initial directory set for source folder panel")
        }

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else {
                showErrorMessage("No folder was selected")
                return
            }

            print("   ✅ User selected source folder: \(url.path)")

            // Save the path to preferences for future folder selections
            UserPreferences.shared.lastUsedInputPath = url.path
            print("   💾 Saved last used input path to preferences")

            // Verify we have read access
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                showErrorMessage("Cannot read from the selected folder. Please check permissions.")
                return
            }

            // Check if folder is on external media
            if isOnExternalMedia(url) {
                // Only show alert if user wants to be asked
                if UserPreferences.shared.askAboutStaging {
                    print("   ⚠️ Selected folder is on external media, showing staging prompt")
                    pendingFolderURL = url
                    showExternalMediaAlert = true
                } else {
                    print("   ⚠️ Selected folder is on external media, proceeding without staging (user preference)")
                    proceedWithFolder(url)
                }
            } else {
                print("   ✅ Selected folder is on internal storage, proceeding normally")
                proceedWithFolder(url)
            }
        } else {
            print("   ❌ User cancelled source folder selection")
        }
    }

    func selectOutputFolder() {
        // Clear external media cache when selecting new folder
        externalMediaCache.removeAll()

        print("\n📂 [DESTINATION FOLDER] Opening destination folder selection panel")
        print("   Current inputFolderURL: \(inputFolderURL?.path ?? "nil")")
        print("   Current outputFolderURL: \(outputFolderURL?.path ?? "nil")")

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select output folder for processed videos"
        openPanel.prompt = "Select Folder"

        // Set initial directory based on user preferences
        let preferences = UserPreferences.shared
        print("   defaultDestinationFolder setting: \(preferences.defaultDestinationFolder.rawValue)")
        print("   customDestinationPath: '\(preferences.customDestinationPath)'")

        if preferences.defaultDestinationFolder == .customPath && !preferences.customDestinationPath.isEmpty {
            let customURL = URL(fileURLWithPath: preferences.customDestinationPath)
            openPanel.directoryURL = customURL
            print("   📁 Using custom default destination path: \(customURL.path)")
        } else if preferences.defaultDestinationFolder == .lastUsed {
            // First check saved path string in preferences
            if !preferences.lastUsedOutputPath.isEmpty {
                let lastUsedURL = URL(fileURLWithPath: preferences.lastUsedOutputPath)
                openPanel.directoryURL = lastUsedURL
                print("   📁 Using saved last used destination path: \(lastUsedURL.path)")
            } else if let lastUsed = outputFolderURL {
                // Fall back to current state if no saved path
                openPanel.directoryURL = lastUsed
                print("   📁 Using current destination folder: \(lastUsed.path)")
            }
        } else {
            print("   📁 No initial directory set for destination folder panel")
        }

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else {
                print("   ❌ No URL returned from panel")
                return
            }

            print("   ✅ User selected destination folder: \(url.path)")
            self.outputFolderURL = url

            // Save the path to preferences for future folder selections
            UserPreferences.shared.lastUsedOutputPath = url.path
            print("   💾 Saved last used output path to preferences")

            // Save the bookmark for future launches (async to prevent freeze)
            saveSecurityScopedBookmark(for: url, key: lastOutputFolderKey)

            // Stop highlighting output folder button once selected
            self.highlightOutputFolderButton = false

            // If both folders are now set and no assets are loaded, automatically trigger scan
            // Only do this after initial app load is complete (not during folder restoration)
            if hasCompletedInitialLoad, let inputURL = inputFolderURL {
                Task {
                    // Check if we have any assets
                    let hasAssets = await viewContext.perform {
                        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
                        fetchRequest.fetchLimit = 1
                        return (try? self.viewContext.count(for: fetchRequest)) ?? 0 > 0
                    }

                    if !hasAssets {
                        print("   🔄 Both folders selected and no assets loaded - auto-triggering scan")
                        await scanInputFolder()
                    } else {
                        print("   ℹ️ Assets already loaded, scan not triggered")
                    }
                }
            }
        } else {
            print("   ❌ User cancelled destination folder selection")
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
        // Cancel any existing processing task
        processingTask?.cancel()

        // Create new processing task
        processingTask = Task {
            self.isLoading = true
            self.isCancelling = false
            self.processingComplete = false // Reset on start
            self.showProcessingModal = true
            self.errorMessage = nil
            self.processingProgress = 0.0
            self.currentProcessingFile = ""
            self.currentFileIndex = 0
            self.totalFilesToProcess = 0

            await processingService.processChanges(
                testMode: testMode,
                outputFolderURL: outputFolderURL,
                statusUpdate: { @Sendable status in
                    Task { @MainActor in self.loadingStatus = status }
                },
                progressUpdate: { @Sendable current, total, filename in
                    Task { @MainActor in
                        self.currentFileIndex = current
                        self.totalFilesToProcess = total
                        self.currentProcessingFile = filename
                        self.processingProgress = total > 0 ? Double(current) / Double(total) : 0.0
                    }
                }
            )

            // Check if we were cancelled
            if Task.isCancelled || self.isCancelling {
                self.loadingStatus = "Processing cancelled."
                await cleanupAfterCancellation()
            } else {
                if testMode {
                    self.loadingStatus = "Test export complete. Check output folder."
                } else {
                    self.loadingStatus = "Processing complete. Ready to export to FCPXML."
                    self.processingComplete = true // Set on complete
                }
            }

            // Clear status after a delay (only if not showing completion dialog)
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if testMode || self.isCancelling {
                    self.loadingStatus = "Idle"
                }
                // Only reset progress values if processing is complete AND modal is dismissed
                // This prevents "0 of 0" showing while completion dialog is still visible
                if !self.processingComplete {
                    self.processingProgress = 0.0
                    self.currentProcessingFile = ""
                    self.currentFileIndex = 0
                    self.totalFilesToProcess = 0
                    self.showProcessingModal = false
                }
            }

            self.isLoading = false
            self.isCancelling = false
        }
    }

    func cancelProcessing() {
        isCancelling = true
        processingTask?.cancel()
        loadingStatus = "Cancelling..."
    }

    private func cleanupAfterCancellation() async {
        // Clean up any partial files or temporary data
        // This could be expanded to delete partial output files
        await MainActor.run {
            self.processingProgress = 0.0
            self.currentProcessingFile = ""
            self.currentFileIndex = 0
            self.totalFilesToProcess = 0
        }
    }

    // MARK: - FCPXML Export

    func exportFCPXML() {
        Task {
            await MainActor.run {
                self.loadingStatus = "Generating FCPXML..."
            }

            // 1. Fetch all assets from Core Data
            let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ManagedVideoAsset.filePath, ascending: true)]

            // We only want to export files that were NOT flagged for deletion
            fetchRequest.predicate = NSPredicate(format: "isFlaggedForDeletion == NO")

            var assets: [ManagedVideoAsset] = []

            // Fetch on the context's queue
            await viewContext.perform {
                do {
                    assets = try self.viewContext.fetch(fetchRequest)
                } catch {
                    Task { @MainActor in
                        self.loadingStatus = "Error fetching assets: \(error.localizedDescription)"
                    }
                }
            }

            await MainActor.run {
                if assets.isEmpty {
                    self.loadingStatus = "No assets to export."
                    return
                }

                do {
                    // 2. Call the exporter
                    try self.fcpExporter.export(assets: assets)
                    self.loadingStatus = "FCPXML export successful."
                } catch {
                    self.loadingStatus = "Error exporting FCPXML: \(error.localizedDescription)"
                }
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        self.errorMessage = message
        self.showError = true
        print("Error: \(message)")
    }

    // MARK: - Multi-Selection Management

    private var lastSelectedIndex: Int?

    func toggleSelection(for asset: ManagedVideoAsset, shiftPressed: Bool = false, allAssets: [ManagedVideoAsset] = []) {
        if shiftPressed, let lastIndex = lastSelectedIndex, !allAssets.isEmpty {
            // Shift-click: select range (adds to existing selection)
            if let currentIndex = allAssets.firstIndex(where: { $0.objectID == asset.objectID }) {
                selectRange(from: lastIndex, to: currentIndex, in: allAssets)
            }
        } else {
            // Normal click: clear all other selections and select only this item
            selectedAssets.removeAll()
            selectedAssets.insert(asset.objectID)

            // Update last selected index
            if let index = allAssets.firstIndex(where: { $0.objectID == asset.objectID }) {
                lastSelectedIndex = index
            }
        }
    }

    private func selectRange(from startIndex: Int, to endIndex: Int, in assets: [ManagedVideoAsset]) {
        let minIndex = min(startIndex, endIndex)
        let maxIndex = max(startIndex, endIndex)

        for index in minIndex...maxIndex {
            if index < assets.count {
                selectedAssets.insert(assets[index].objectID)
            }
        }

        lastSelectedIndex = endIndex
    }

    func clearSelection() {
        selectedAssets.removeAll()
        lastSelectedIndex = nil
    }

    func selectAll() {
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
        do {
            let allAssets = try viewContext.fetch(fetchRequest)
            selectedAssets = Set(allAssets.map { $0.objectID })
        } catch {
            showErrorMessage("Failed to select all: \(error.localizedDescription)")
        }
    }

    func isSelected(_ asset: ManagedVideoAsset) -> Bool {
        return selectedAssets.contains(asset.objectID)
    }

    // MARK: - Context Menu Actions

    func markForDeletion(assets: [ManagedVideoAsset], flagged: Bool) {
        for asset in assets {
            asset.objectWillChange.send()
            asset.isFlaggedForDeletion = flagged
        }
        try? viewContext.save()
        viewContext.processPendingChanges()
        print("✅ Marked \(assets.count) video(s) for deletion: \(flagged)")
    }

    func applyLUTToAssets(assets: [ManagedVideoAsset], lutId: String?) {
        for asset in assets {
            asset.objectWillChange.send()
            asset.selectedLUTId = lutId ?? ""
        }
        try? viewContext.save()
        viewContext.processPendingChanges()
        print("✅ Applied LUT to \(assets.count) video(s)")
    }

    func toggleBakeLUT(assets: [ManagedVideoAsset], enabled: Bool) {
        for asset in assets {
            asset.objectWillChange.send()
            asset.bakeInLUT = enabled
        }
        try? viewContext.save()
        viewContext.processPendingChanges()
        print("✅ Set 'Bake in LUT' to \(enabled) for \(assets.count) video(s)")
    }

    /// Export only the selected assets to a chosen folder
    func exportSelectedAssets(_ assets: [ManagedVideoAsset]) {
        // Show folder picker for output destination
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Export Folder"
        panel.message = "Select where to export the selected \(assets.count) file\(assets.count == 1 ? "" : "s")"

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let outputURL = panel.url else { return }

            // Start processing in background
            Task { @MainActor in
                self.showProcessingModal = true
                self.currentProcessingFile = "Preparing to export selected files..."

                await self.processingService.processSelectedAssets(
                    assets,
                    outputFolderURL: outputURL,
                    statusUpdate: { status in
                        Task { @MainActor in
                            self.currentProcessingFile = status
                        }
                    },
                    progressUpdate: { current, total, fileName in
                        Task { @MainActor in
                            self.processingProgress = Double(current) / Double(total)
                            self.currentProcessingFile = fileName
                        }
                    }
                )

                self.showProcessingModal = false
                self.processingProgress = 0.0

                // Show completion alert
                let alert = NSAlert()
                alert.messageText = "Export Complete"
                alert.informativeText = "Successfully exported \(assets.count) file\(assets.count == 1 ? "" : "s") to:\n\(outputURL.path)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Reveal in Finder")

                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: outputURL.path)
                }
            }
        }
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

    // MARK: - External Media Detection and Staging

    /// Check if a folder is on external media (not the main system drive)
    func isOnExternalMedia(_ url: URL) -> Bool {
        // Use cache to avoid repeated expensive disk I/O operations
        let cacheKey = url.path
        if let cached = externalMediaCache[cacheKey] {
            return cached
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey])

            // Check if it's removable (USB, SD card, etc.) or ejectable (external drives)
            let isRemovable = resourceValues.volumeIsRemovable ?? false
            let isEjectable = resourceValues.volumeIsEjectable ?? false
            let isInternal = resourceValues.volumeIsInternal ?? true

            print("📦 Volume check for \(url.lastPathComponent):")
            print("   Removable: \(isRemovable)")
            print("   Ejectable: \(isEjectable)")
            print("   Internal: \(isInternal)")

            // Consider it external if it's removable, ejectable, or not internal
            let result = isRemovable || isEjectable || !isInternal

            // Cache the result
            externalMediaCache[cacheKey] = result

            return result
        } catch {
            print("❌ Failed to check volume properties: \(error)")
            // Cache negative result
            externalMediaCache[cacheKey] = false
            return false
        }
    }

    /// Proceed with scanning the folder (after staging check or user choice)
    func proceedWithFolder(_ url: URL) {
        // Set the input folder
        self.inputFolderURL = url

        // Save the bookmark for future launches
        saveSecurityScopedBookmark(for: url, key: lastInputFolderKey)

        // Stop highlighting input folder button and start highlighting output folder button
        self.highlightInputFolderButton = false
        self.highlightOutputFolderButton = true

        // Set default output folder based on test mode
        updateOutputFolder()

        // Scanning deferred - user must explicitly initiate via Scan button or similar
        self.loadingStatus = "Folder selected. Ready to scan."
        print("   ℹ️ Folder selected, scanning deferred until explicitly initiated")
    }

    /// Stage files from external media to local folder using rsync (fast like Finder)
    func stageFromExternalMedia(sourceURL: URL, destinationURL: URL? = nil) {
        Task {
            self.isStaging = true
            self.stagingProgress = 0.0

            // Create staging folder
            let stagingURL: URL
            if let destURL = destinationURL {
                stagingURL = destURL
            } else {
                // Default to Desktop with auto-generated name
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let folderName = sourceURL.lastPathComponent
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: ".")
                stagingURL = desktopURL.appendingPathComponent("Staged-\(folderName)-\(timestamp)", isDirectory: true)
            }

            await MainActor.run {
                self.stagingStatus = "Preparing to stage files..."
            }

            do {
                try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
                print("📂 Created staging folder: \(stagingURL.path)")

                await MainActor.run {
                    self.stagingStatus = "Copying files from external media..."
                }

                // Simplest and fastest approach: just copy everything!
                // The scanner will filter for video files anyway
                // This avoids complex rsync filters and is just as fast
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")

                // Optimized rsync arguments (compatible with older macOS rsync):
                // -a: archive mode (preserves structure)
                // --no-perms --no-owner --no-group: skip permission/ownership (faster, avoids permission errors)
                // -q: quiet mode (no verbose output, just errors)
                process.arguments = [
                    "-a",
                    "--no-perms",
                    "--no-owner",
                    "--no-group",
                    "-q",
                    sourceURL.path + "/",
                    stagingURL.path
                ]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                print("🚀 Starting rsync transfer...")
                print("🚀 Source: \(sourceURL.path)")
                print("🚀 Destination: \(stagingURL.path)")

                try process.run()

                // Simple progress update without parsing
                await MainActor.run {
                    self.stagingProgress = 0.5
                    self.stagingStatus = "Copying files..."
                }

                process.waitUntilExit()

                // Read all output after completion
                let outputData = try? outputPipe.fileHandleForReading.readToEnd()
                let errorData = try? errorPipe.fileHandleForReading.readToEnd()

                let outputText = outputData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let errorText = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

                if process.terminationStatus == 0 {
                    print("✅ rsync completed successfully")
                    if !outputText.isEmpty {
                        print("📝 Output: \(outputText)")
                    }

                    await MainActor.run {
                        self.stagingProgress = 1.0
                        self.stagingStatus = "Staging complete!"
                        self.isStaging = false
                    }

                    try? await Task.sleep(nanoseconds: 500_000_000)

                    await MainActor.run {
                        self.proceedWithFolder(stagingURL)
                    }
                } else {
                    print("❌ rsync failed with status \(process.terminationStatus)")
                    print("❌ stdout: \(outputText)")
                    print("❌ stderr: \(errorText)")

                    let errorMessage = !errorText.isEmpty ? errorText :
                                      (!outputText.isEmpty ? outputText :
                                       "rsync failed with exit code \(process.terminationStatus). No error output available.")

                    throw NSError(domain: "StagingError", code: Int(process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: "Staging failed:\n\n\(errorMessage)"])
                }

            } catch {
                await MainActor.run {
                    self.isStaging = false
                    self.showErrorMessage("Failed to stage files: \(error.localizedDescription)")
                }
            }
        }
    }

    /// User chose to proceed without staging
    func proceedWithoutStaging() {
        guard let url = pendingFolderURL else { return }
        pendingFolderURL = nil
        proceedWithFolder(url)
    }

    /// User chose to stage files
    func proceedWithStaging() {
        guard let url = pendingFolderURL else { return }

        // Let user select staging destination
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "Staged-\(url.lastPathComponent)"
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        savePanel.message = "Choose where to stage the media files locally"
        savePanel.prompt = "Stage Here"

        if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
            pendingFolderURL = nil
            stageFromExternalMedia(sourceURL: url, destinationURL: destinationURL)
        } else {
            // User cancelled, just proceed without staging
            proceedWithoutStaging()
        }
    }
}
