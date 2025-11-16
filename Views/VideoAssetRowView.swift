//
//  VideoAssetRowView.swift
//  VideoCullingApp
//

import SwiftUI

struct VideoAssetRowView: View {
    // 1. This view observes a single asset.
    // When the asset changes, this view (and only this view) updates.
    @ObservedObject var asset: ManagedVideoAsset
    
    // 2. Local state for the trim slider values
    // We use @State for the sliders for responsiveness.
    // We only commit the change to Core Data `onEnded`.
    @State private var localTrimStart: Double = 0.0
    @State private var localTrimEnd: Double = 1.0 // Use 1.0 as "full duration"
    
    // 3. Check if the user has set trim points
    private var isTrimmed: Bool {
        // Use a small epsilon to avoid floating point precision issues
        localTrimStart > 0.001 || localTrimEnd < 0.999
    }
    
    // 4. Calculate estimated values
    private var estimatedDuration: Double {
        (asset.duration * (localTrimEnd - localTrimStart))
    }
    
    private var estimatedSize: Int64 {
        if asset.duration == 0 { return 0 }
        return Int64(Double(asset.fileSize) * (localTrimEnd - localTrimStart))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // --- COLUMN 1: Player & Trimmer (Expanded) ---
            PlayerView(
                asset: asset,
                localTrimStart: $localTrimStart,
                localTrimEnd: $localTrimEnd
            )
            .frame(width: 400) // Wider width, height will fill available space

            // --- COLUMN 2: Editable Fields ---
            EditableFieldsView(asset: asset)
                .frame(maxWidth: 350, alignment: .leading)

            // --- COLUMN 3: Metadata (Compressed) ---
            MetadataView(
                asset: asset,
                isTrimmed: isTrimmed,
                estimatedDuration: estimatedDuration,
                estimatedSize: estimatedSize
            )
            .frame(width: 200, alignment: .leading)

        }
        .padding(.horizontal)
        .onAppear {
            // Load initial trim values when the view appears
            self.localTrimStart = asset.trimStartTime
            // 0.0 in Core Data means "end of clip", which we represent as 1.0 (100%)
            self.localTrimEnd = (asset.trimEndTime == 0) ? 1.0 : asset.trimEndTime
        }
        .onChange(of: localTrimStart) { newValue in
            // When slider *finishes* moving, save to Core Data
            // Note: This requires a slider with an `onEditingChanged` callback
            // For a simple slider, this will save on every change.
            asset.trimStartTime = newValue
            saveContext()
        }
        .onChange(of: localTrimEnd) { newValue in
            // Save trim changes back to Core Data
            asset.trimEndTime = newValue
            saveContext()
        }
    }
    
    private func saveContext() {
        // A helper to save the context.
        // In a real app, you'd add error handling and debounce this.
        try? asset.managedObjectContext?.save()
    }
}
