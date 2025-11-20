//
//  VideoAssetRowView.swift
//  VideoCullingApp
//

import SwiftUI

struct VideoAssetRowView: View {
    // 1. This view observes a single asset.
    // When the asset changes, this view (and only this view) updates.
    @ObservedObject var asset: ManagedVideoAsset
    var viewModel: ContentViewModel  // Not @ObservedObject to avoid type-checker complexity
    var allAssets: [ManagedVideoAsset] = []  // For shift-click selection
    var onVideoEnded: (() -> Void)?  // Callback for play-through
    var shouldAutoPlay: Bool = false  // Trigger for auto-play
    var isSelected: Bool = false  // Indicates if this row is the active/selected row for hotkeys

    private var isMultiSelected: Bool {
        viewModel.isSelected(asset)
    }

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

    private var selectionBackgroundColor: Color {
        isMultiSelected ? Color.blue.opacity(0.1) : Color.clear
    }

    private var selectionBorderColor: Color {
        isMultiSelected ? Color.blue.opacity(0.5) : Color.clear
    }

    private var checkboxIconName: String {
        isMultiSelected ? "checkmark.square.fill" : "square"
    }

    private var checkboxIconColor: Color {
        isMultiSelected ? .blue : .secondary
    }

    private var checkboxColumn: some View {
        VStack {
            Button(action: {
                let shiftPressed = NSEvent.modifierFlags.contains(.shift)
                viewModel.toggleSelection(for: asset, shiftPressed: shiftPressed, allAssets: allAssets)
            }) {
                Image(systemName: checkboxIconName)
                    .font(.system(size: 24))
                    .foregroundColor(checkboxIconColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Spacer()
        }
        .frame(width: 40)
    }

    private var playerColumn: some View {
        PlayerView(
            asset: asset,
            localTrimStart: $localTrimStart,
            localTrimEnd: $localTrimEnd,
            onVideoEnded: onVideoEnded,
            shouldAutoPlay: shouldAutoPlay,
            isSelected: isSelected
        )
        .frame(width: 400)
    }

    private var editableFieldsColumn: some View {
        EditableFieldsView(asset: asset, viewModel: viewModel)
            .frame(width: 350, alignment: .leading)
    }

    private var metadataColumn: some View {
        MetadataView(
            asset: asset,
            isTrimmed: isTrimmed,
            estimatedDuration: estimatedDuration,
            estimatedSize: estimatedSize
        )
        .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading)
    }

    private var enrichedMetadataColumn: some View {
        EnrichedMetadataView(asset: asset)
            .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func makeRowContent() -> some View {
        HStack(alignment: .top, spacing: 16) {
            checkboxColumn
            playerColumn
            editableFieldsColumn
            metadataColumn
            enrichedMetadataColumn
        }
    }

    var body: some View {
        makeRowContent()
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectionBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectionBorderColor, lineWidth: 2)
            )
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
