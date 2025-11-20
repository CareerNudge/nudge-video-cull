//
//  VideoAssetRowView.swift
//  VideoCullingApp
//

import SwiftUI

struct VideoAssetRowView: View {
    // 1. This view observes a single asset.
    // When the asset changes, this view (and only this view) updates.
    @ObservedObject var asset: ManagedVideoAsset
    var onVideoEnded: (() -> Void)?  // Callback for play-through
    var shouldAutoPlay: Bool = false  // Trigger for auto-play
    var isSelected: Bool = false  // Indicates if this row is the active/selected row for hotkeys

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
        HStack(alignment: .top, spacing: 16) {

            // --- COLUMN 1: Player & Trimmer (Expanded) ---
            PlayerView(
                asset: asset,
                localTrimStart: $localTrimStart,
                localTrimEnd: $localTrimEnd,
                onVideoEnded: onVideoEnded,
                shouldAutoPlay: shouldAutoPlay,
                isSelected: isSelected
            )
            .frame(width: 400) // Fixed width to match header

            // --- COLUMN 2: Editable Fields (Top-aligned, Keywords fills vertical space) ---
            EditableFieldsView(asset: asset)
                .frame(width: 350, alignment: .leading) // Fixed width to match header

            // --- COLUMN 3: File Metadata (Standard) ---
            MetadataView(
                asset: asset,
                isTrimmed: isTrimmed,
                estimatedDuration: estimatedDuration,
                estimatedSize: estimatedSize
            )
            .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading) // Flexible width, fills remaining space

            // --- COLUMN 4: Enriched Camera Metadata (Sony XML) ---
            EnrichedMetadataView(asset: asset)
                .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading) // Flexible width, fills remaining space

        }
        .onAppear {
            // Load initial trim values when the view appears
            self.localTrimStart = asset.trimStartTime
            // 0.0 in Core Data means "end of clip", which we represent as 1.0 (100%)
            self.localTrimEnd = (asset.trimEndTime == 0) ? 1.0 : asset.trimEndTime
        }
        // ✅ REMOVED: onChange handlers that were causing 100+ Core Data saves per second
        // Save logic moved to PlayerView.swift .onEnded callbacks (lines 216-228, 256-268)
    }
}
