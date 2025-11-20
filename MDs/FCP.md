# Nudge Video Cull - Feature Update: FCPXML Export

## 1. Project Goal

Modify the existing processing screen. After all "Process Culling Job" file operations (deleting, trimming, etc.) are complete, the progress bar should show as 100% (or "Complete") and a new button, "Export to FCPXML," should appear.

Clicking this button will:
1.  Fetch all video assets from the current project.
2.  Generate a valid `.fcpxml` file that includes all user-defined ratings, keywords, and trim points.
3.  Present an `NSSavePanel` for the user to save this `.fcpxml` file to their system.

---

## 2. Modifications to ViewModels

### File: `ViewModels/ContentViewModel.swift`

We need to add state to control the visibility of the new button and a function to trigger the export.

1.  **Add New `@Published` Properties:**
    * Add a boolean to track if processing is complete:
        ```swift
        @Published var processingComplete: Bool = false
        ```
    * Add a property to hold the FCPXML exporter logic:
        ```swift
        private let fcpExporter = FCPXMLExporter()
        ```

2.  **Modify `applyChanges()` Function:**
    * At the *beginning* of the function, set `processingComplete = false`.
    * At the *very end* of the function (after all processing and saving is finished), set `processingComplete = true` and update the status:

    ```swift
    // Inside ContentViewModel.swift
    
    @MainActor
    func applyChanges() async {
        self.isLoading = true
        self.processingComplete = false // Reset on start
        
        await processingService.processChanges(statusUpdate: { status in
            Task { @MainActor in self.loadingStatus = status }
        })
        
        self.isLoading = false
        self.processingComplete = true // Set on complete
        self.loadingStatus = "Processing complete. Ready to export."
    }
    ```

3.  **Add New `exportFCPXML()` Function:**
    * This function will fetch the assets and call the new exporter service.

    ```swift
    // Inside ContentViewModel.swift
    
    @MainActor
    func exportFCPXML() {
        self.loadingStatus = "Generating FCPXML..."
        
        // 1. Fetch all assets from Core Data
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ManagedVideoAsset.filePath, ascending: true)]
        
        // We only want to export files that were NOT flagged for deletion
        fetchRequest.predicate = NSPredicate(format: "isFlaggedForDeletion == NO")
        
        do {
            let assets = try viewContext.fetch(fetchRequest)
            if assets.isEmpty {
                self.loadingStatus = "No assets to export."
                return
            }
            
            // 2. Call the exporter
            try fcpExporter.export(assets: assets)
            self.loadingStatus = "FCPXML export successful."
            
        } catch {
            self.loadingStatus = "Error exporting FCPXML: \(error.localizedDescription)"
        }
    }
    ```

## 3. Modifications to Views

### File: `Views/ContentView.swift` (or your processing view)

Modify the view that shows the progress bar to also show the new button.

1.  **Locate the Progress Bar / Status Text:** Find the `HStack` in your `MainAppView` (or equivalent) that currently shows the `ProgressView` and `loadingStatus`.
2.  **Add Conditional Button:** Modify the logic to:
    * Show the `ProgressView` if `viewModel.isLoading == true`.
    * Show the `Button` if `viewModel.processingComplete == true` AND `viewModel.isLoading == false`.

```swift
// In Views/MainAppView.swift (or ContentView.swift)
// Inside the "TOP TOOLBAR" HStack

HStack {
    // ... "Select Folder" button ...
    
    Spacer()
    
    // --- PROCESSING STATUS LOGIC ---
    if viewModel.isLoading {
        ProgressView().scaleEffect(0.5)
        Text(viewModel.loadingStatus)
            .font(.subheadline)
            .foregroundColor(.secondary)
    } else if viewModel.processingComplete {
        // Processing is done, show the export button
        Text(viewModel.loadingStatus) // "Processing complete."
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        Button(action: viewModel.exportFCPXML) {
            Label("Export to FCPXML", systemImage: "arrow.down.doc")
        }
        .tint(.green) // Make it stand out
    } else {
        // Idle state, show nothing or just status
        Text(viewModel.loadingStatus)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    // --- END PROCESSING LOGIC ---
    
    Spacer()
    
    // ... "Apply Changes" button ...
}