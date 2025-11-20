//
//  GalleryView.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData
import AVFoundation

struct GalleryView: View {
    @State private var currentPlayingIndex: Int? = nil
    @State private var selectedAssetIndex: Int = 0 // Shared between horizontal and vertical views
    @ObservedObject private var preferences = UserPreferences.shared
    @StateObject private var viewModel: ContentViewModel
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: ContentViewModel(context: context))
    }

    // Note: We can't use @FetchRequest with dynamic sort descriptors directly
    // Instead we'll sort the results manually in the body
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ManagedVideoAsset.filePath, ascending: true)],
        animation: .default)
    private var videoAssets: FetchedResults<ManagedVideoAsset>

    // Sorted assets based on current sort order
    private var sortedAssets: [ManagedVideoAsset] {
        switch viewModel.sortOrder {
        case .newestFirst:
            return videoAssets.sorted { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }
        case .oldestFirst:
            return videoAssets.sorted { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
        }
    }

    // Calculate statistics
    private var statistics: (totalClips: Int, originalDuration: Double, estimatedDuration: Double, originalSize: Double, estimatedSize: Double) {
        let totalClips = videoAssets.count
        var originalDuration = 0.0
        var estimatedDuration = 0.0
        var originalSize = 0.0
        var estimatedSize = 0.0

        for asset in videoAssets {
            // Always include in original totals (starting point)
            originalDuration += asset.duration
            originalSize += Double(asset.fileSize)

            // Only include in estimated totals if NOT flagged for deletion
            if !asset.isFlaggedForDeletion {
                // Calculate estimated duration after trim
                let trimStart = asset.trimStartTime
                let trimEnd = asset.trimEndTime > 0 ? asset.trimEndTime : 1.0
                let trimmedDuration = asset.duration * (trimEnd - trimStart)
                estimatedDuration += trimmedDuration

                // Estimate size proportionally to duration
                let sizeRatio = trimmedDuration / asset.duration
                estimatedSize += Double(asset.fileSize) * sizeRatio
            }
        }

        return (totalClips, originalDuration, estimatedDuration, originalSize, estimatedSize)
    }

    var body: some View {
        Group {
            // Conditionally render based on orientation preference
            if preferences.orientation == .horizontal {
                HorizontalGalleryView(
                    videoAssets: Array(sortedAssets),
                    statistics: statistics,
                    currentPlayingIndex: $currentPlayingIndex,
                    selectedAssetIndex: $selectedAssetIndex
                )
            } else {
                verticalGalleryView
            }
        }
        .onAppear {
            setupHotkeyCallbacks()
        }
        .onChange(of: hotkeyManager.navigateNextTrigger) { _ in
            if selectedAssetIndex < sortedAssets.count - 1 {
                selectedAssetIndex += 1
                print("⌨️ Hotkey: Navigate next → index \(selectedAssetIndex)")
            }
        }
        .onChange(of: hotkeyManager.navigatePreviousTrigger) { _ in
            if selectedAssetIndex > 0 {
                selectedAssetIndex -= 1
                print("⌨️ Hotkey: Navigate previous → index \(selectedAssetIndex)")
            }
        }
    }

    private var verticalGalleryView: some View {
        VStack(spacing: 0) {
            // Sticky Header
            if !videoAssets.isEmpty {
                VStack(spacing: 0) {
                    // Column Headers
                    HStack(alignment: .center, spacing: 16) {
                        // Column 1: Preview and Trim - Fixed 400px
                        Text("Preview and Trim")
                            .font(.headline)
                            .frame(width: 400, alignment: .leading)

                        // Column 2: Video Import Settings - Fixed 350px
                        Text("Video Import Settings")
                            .font(.headline)
                            .frame(width: 350, alignment: .leading)

                        // Column 3: File Metadata - Flexible, min 250px
                        Text("File Metadata")
                            .font(.headline)
                            .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading)

                        // Column 4: Camera Metadata - Flexible, min 250px
                        Text("Camera Metadata")
                            .font(.headline)
                            .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12) // Match VideoAssetRowView wrapper padding
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()
                }
            }

            // Main content with ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if videoAssets.isEmpty {
                            Text("Select a folder to begin.")
                                .font(.title)
                                .foregroundColor(.secondary)
                                .padding(.top, 100)
                        } else {
                            ForEach(Array(sortedAssets.enumerated()), id: \.element.id) { index, asset in
                                VStack(spacing: 0) {
                                    VideoAssetRowView(
                                        asset: asset,
                                        onVideoEnded: {
                                            handleVideoEnded(currentIndex: index, proxy: proxy)
                                        },
                                        shouldAutoPlay: currentPlayingIndex == index,
                                        isSelected: selectedAssetIndex == index
                                    )
                                    .padding(.top, 20)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedAssetIndex == index ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                }
                                .id(asset.id)
                                .onTapGesture {
                                    selectedAssetIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }

            // Sticky Footer
            if !videoAssets.isEmpty {
                VStack(spacing: 0) {
                    Divider()

                    HStack(spacing: 32) {
                        // Total Clips
                        HStack(spacing: 8) {
                            Text("Total Clips:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(statistics.totalClips)")
                                .font(.subheadline.bold())
                        }

                        // Total Duration
                        HStack(spacing: 8) {
                            Text("Total Duration:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatDuration(statistics.originalDuration)) → \(formatDuration(statistics.estimatedDuration))")
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedDuration < statistics.originalDuration ? .green : .primary)
                        }

                        // Total File Size
                        HStack(spacing: 8) {
                            Text("Total File Size:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatFileSize(statistics.originalSize)) → \(formatFileSize(statistics.estimatedSize))")
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedSize < statistics.originalSize ? .green : .primary)
                        }

                        Spacer()

                        // Total Space Savings (far right)
                        HStack(spacing: 8) {
                            Text("Total Space Savings:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatFileSize(max(0, statistics.originalSize - statistics.estimatedSize)))
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedSize < statistics.originalSize ? .green : .orange)
                        }
                    }
                    .padding(.horizontal) // Match VideoAssetRowView padding
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
    }

    // MARK: - Hotkey Setup

    private func setupHotkeyCallbacks() {
        print("⌨️ Hotkey callbacks ready (using Published triggers)")
        // Hotkeys are now handled through onChange modifiers watching
        // hotkeyManager.navigateNextTrigger and navigatePreviousTrigger
    }

    // MARK: - Play-Through Support

    private func handleVideoEnded(currentIndex: Int, proxy: ScrollViewProxy) {
        guard preferences.videoPlayThroughEnabled else {
            print("🎬 Play-through is disabled in GalleryView")
            return
        }

        print("🎬 Video at index \(currentIndex) ended, advancing to next video")

        // Calculate next index
        let nextIndex = currentIndex + 1

        // Check if there's a next video
        guard nextIndex < sortedAssets.count else {
            print("🎬 Reached end of video list, no more videos to play")
            currentPlayingIndex = nil
            return
        }

        // Get the next asset
        let nextAsset = sortedAssets[nextIndex]

        print("🎬 Scrolling to next video: \(nextAsset.fileName ?? "unknown")")

        // Scroll to the next video with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(nextAsset.id, anchor: .top)
        }

        // Update current playing index after a brief delay to ensure scroll completes
        // This triggers the auto-play on the next video
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            print("🎬 Triggering auto-play for video at index \(nextIndex)")
            currentPlayingIndex = nextIndex
        }
    }

    // Helper function to format duration
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // Helper function to format file size
    private func formatFileSize(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Horizontal Gallery View
struct HorizontalGalleryView: View {
    let videoAssets: [ManagedVideoAsset]
    let statistics: (totalClips: Int, originalDuration: Double, estimatedDuration: Double, originalSize: Double, estimatedSize: Double)
    @Binding var currentPlayingIndex: Int?
    @Binding var selectedAssetIndex: Int // Now shared with parent
    @ObservedObject private var preferences = UserPreferences.shared

    // Local state for trim sliders and deletion flag
    @State private var localTrimStart: Double = 0.0
    @State private var localTrimEnd: Double = 1.0
    @State private var localIsFlaggedForDeletion: Bool = false
    @State private var scrubPosition: Double? = nil // For scrubbing preview

    private var selectedAsset: ManagedVideoAsset? {
        guard !videoAssets.isEmpty, selectedAssetIndex < videoAssets.count else { return nil }
        return videoAssets[selectedAssetIndex]
    }

    private var isTrimmed: Bool {
        localTrimStart > 0.001 || localTrimEnd < 0.999
    }

    var body: some View {
        VStack(spacing: 0) {
            if videoAssets.isEmpty {
                // Empty state
                VStack {
                    Text("Select a folder to begin.")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Main content area
                HStack(spacing: 0) {
                    // Left side: Large video player (no overlay controls)
                    if let asset = selectedAsset {
                        CleanVideoPlayerView(
                            asset: asset,
                            localTrimStart: $localTrimStart,
                            localTrimEnd: $localTrimEnd,
                            isFlaggedForDeletion: $localIsFlaggedForDeletion,
                            scrubPosition: $scrubPosition,
                            shouldAutoPlay: currentPlayingIndex == selectedAssetIndex,
                            onVideoEnded: {
                                handleVideoEnded()
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(selectedAssetIndex) // Force reload when selection changes
                    }

                    Divider()

                    // Right side: Compact controls sidebar
                    if let asset = selectedAsset {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // SECTION 1: Editable fields
                                EditableFieldsView(asset: asset)

                                Divider()

                                // SECTION 2: File Metadata
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("File Metadata")
                                        .font(.headline)

                                    MetadataView(
                                        asset: asset,
                                        isTrimmed: isTrimmed,
                                        estimatedDuration: calculateEstimatedDuration(for: asset),
                                        estimatedSize: calculateEstimatedSize(for: asset)
                                    )
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                        )
                                )

                                // SECTION 3: Camera Metadata (if available)
                                if asset.hasXMLSidecar {
                                    Divider()

                                    VStack(alignment: .leading, spacing: 8) {
                                        EnrichedMetadataView(asset: asset)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(16)
                        }
                        .frame(width: 400)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                }

                Divider()

                // Bottom: Thumbnail filmstrip
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(spacing: 12) {
                                ForEach(Array(videoAssets.enumerated()), id: \.element.id) { index, asset in
                                    ThumbnailCardView(
                                        asset: asset,
                                        isSelected: index == selectedAssetIndex,
                                        onTap: {
                                            withAnimation {
                                                selectedAssetIndex = index
                                                currentPlayingIndex = nil
                                                // Load values for new selection
                                                if let newAsset = videoAssets[safe: index] {
                                                    localTrimStart = newAsset.trimStartTime
                                                    localTrimEnd = newAsset.trimEndTime > 0 ? newAsset.trimEndTime : 1.0
                                                    localIsFlaggedForDeletion = newAsset.isFlaggedForDeletion
                                                }
                                            }
                                        }
                                    )
                                    .id(asset.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .frame(height: 200)
                        .background(Color(NSColor.windowBackgroundColor))
                        .onChange(of: selectedAssetIndex) { newIndex in
                            if newIndex < videoAssets.count {
                                proxy.scrollTo(videoAssets[newIndex].id, anchor: .center)
                            }
                        }
                    }

                    Divider()

                    // Statistics footer
                    HStack(spacing: 32) {
                        HStack(spacing: 8) {
                            Text("Total Clips:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(statistics.totalClips)")
                                .font(.subheadline.bold())
                        }

                        HStack(spacing: 8) {
                            Text("Total Duration:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatDuration(statistics.originalDuration)) → \(formatDuration(statistics.estimatedDuration))")
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedDuration < statistics.originalDuration ? .green : .primary)
                        }

                        HStack(spacing: 8) {
                            Text("Total File Size:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatFileSize(statistics.originalSize)) → \(formatFileSize(statistics.estimatedSize))")
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedSize < statistics.originalSize ? .green : .primary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Text("Total Space Savings:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatFileSize(max(0, statistics.originalSize - statistics.estimatedSize)))
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedSize < statistics.originalSize ? .green : .orange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .onAppear {
            // Load initial values
            if let asset = selectedAsset {
                localTrimStart = asset.trimStartTime
                localTrimEnd = asset.trimEndTime > 0 ? asset.trimEndTime : 1.0
                localIsFlaggedForDeletion = asset.isFlaggedForDeletion
            }
        }
        .onChange(of: selectedAssetIndex) { _ in
            // Update values when selection changes
            if let asset = selectedAsset {
                localTrimStart = asset.trimStartTime
                localTrimEnd = asset.trimEndTime > 0 ? asset.trimEndTime : 1.0
                localIsFlaggedForDeletion = asset.isFlaggedForDeletion
            }
        }
        .background(
            // Hidden buttons for navigation keyboard shortcuts
            HStack {
                // Left arrow = next video (user's preference)
                Button("") { navigateToNext() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .hidden()

                // Right arrow = previous video (user's preference)
                Button("") { navigateToPrevious() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .hidden()
            }
        )
    }

    private func navigateToNext() {
        if selectedAssetIndex < videoAssets.count - 1 {
            selectedAssetIndex += 1
            currentPlayingIndex = nil // Stop any auto-playing
        }
    }

    private func navigateToPrevious() {
        if selectedAssetIndex > 0 {
            selectedAssetIndex -= 1
            currentPlayingIndex = nil // Stop any auto-playing
        }
    }

    private func handleVideoEnded() {
        guard preferences.videoPlayThroughEnabled else { return }

        // Advance to next video
        if selectedAssetIndex < videoAssets.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                selectedAssetIndex += 1
                currentPlayingIndex = selectedAssetIndex
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatFileSize(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func calculateEstimatedDuration(for asset: ManagedVideoAsset) -> Double {
        let trimStart = asset.trimStartTime
        let trimEnd = asset.trimEndTime > 0 ? asset.trimEndTime : 1.0
        return asset.duration * (trimEnd - trimStart)
    }

    private func calculateEstimatedSize(for asset: ManagedVideoAsset) -> Int64 {
        let trimStart = asset.trimStartTime
        let trimEnd = asset.trimEndTime > 0 ? asset.trimEndTime : 1.0
        let trimmedDuration = asset.duration * (trimEnd - trimStart)
        let sizeRatio = trimmedDuration / asset.duration
        return Int64(Double(asset.fileSize) * sizeRatio)
    }
}

// MARK: - Array Safe Subscript Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Clean Video Player View (for Horizontal Gallery)
struct CleanVideoPlayerView: View {
    @ObservedObject var asset: ManagedVideoAsset
    @Binding var localTrimStart: Double
    @Binding var localTrimEnd: Double
    @Binding var isFlaggedForDeletion: Bool
    @Binding var scrubPosition: Double?
    var shouldAutoPlay: Bool = false
    var onVideoEnded: (() -> Void)?

    @State private var player: AVPlayer?
    @State private var thumbnail: NSImage?
    @State private var isPlaying = false
    @State private var currentPosition: Double = 0.0
    @State private var timeObserver: Any?
    @State private var boundaryObserver: Any? // Efficient trim end detection
    @State private var observerPlayer: AVPlayer? // Track which player owns the observer
    @State private var previewImage: NSImage? // For scrubbing preview
    @State private var imageGenerator: AVAssetImageGenerator?
    @State private var ciContext: CIContext? // Hardware-accelerated context for LUT application
    @ObservedObject private var lutManager = LUTManager.shared
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        VStack(spacing: 0) {
            // Import/Deletion status toggle (above video)
            HStack(spacing: 0) {
                // Left side: Checkmark (Import/Preserve)
                Button(action: {
                    if isFlaggedForDeletion {
                        isFlaggedForDeletion = false
                        asset.isFlaggedForDeletion = false
                        try? asset.managedObjectContext?.save()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(preserveText)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isFlaggedForDeletion ? .secondary : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isFlaggedForDeletion ? Color.gray.opacity(0.1) : Color.blue.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                // Right side: X (Delete/Don't Import)
                Button(action: {
                    if !isFlaggedForDeletion {
                        isFlaggedForDeletion = true
                        asset.isFlaggedForDeletion = true
                        try? asset.managedObjectContext?.save()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(deleteText)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isFlaggedForDeletion ? .red : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isFlaggedForDeletion ? Color.red.opacity(0.15) : Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Video display area (no overlay controls)
            GeometryReader { geometry in
                ZStack {
                    if isPlaying, let player = player {
                        // Active video player
                        OptimizedVideoPlayerView(player: player)
                            .onAppear {
                                player.play()
                            }
                    } else {
                        // Show preview image when scrubbing, otherwise show thumbnail
                        if let previewImage = previewImage {
                            Image(nsImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let thumbnail = thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Rectangle()
                                .fill(Color.black)
                        }
                    }

                    // Grey overlay when flagged for deletion
                    if isFlaggedForDeletion {
                        Rectangle()
                            .fill(Color.gray.opacity(0.7))
                            .allowsHitTesting(false)
                    }

                    // Toggle Gallery Mode button in bottom-right corner
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                if isPlaying {
                                    player?.pause()
                                    isPlaying = false
                                }
                                // Don't manually call removeTimeObserver() - let .onDisappear handle cleanup
                                preferences.orientation = preferences.orientation == .vertical ? .horizontal : .vertical
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 30, height: 30)

                                    Image(systemName: preferences.orientation == .vertical ? "rectangle.split.3x1" : "rectangle.split.2x1")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14)
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("galleryModeButton")
                            .padding(8)
                        }
                    }
                }
            }

            // Playback and trim controls BELOW video (not overlaying)
            VStack(spacing: 8) {
                // Integrated playback and trim controls on single line
                HStack(spacing: 16) {
                    // Play/Pause button
                    Button(action: {
                        if isPlaying {
                            player?.pause()
                            isPlaying = false
                        } else {
                            // If at or near the end, restart from beginning
                            if currentPosition >= localTrimEnd - 0.01 {
                                currentPosition = localTrimStart
                                if let player = player {
                                    let seekTime = CMTime(seconds: asset.duration * localTrimStart, preferredTimescale: 600)
                                    player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                }
                            }
                            startPlayback()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                    .accessibilityIdentifier("playPauseButton")
                    .disabled(isFlaggedForDeletion)

                    // Time display
                    Text(formatTime(currentPosition * asset.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50)

                    // Integrated slider with trim handles and playhead
                    GeometryReader { geometry in
                        let trackWidth = geometry.size.width
                        let trimStartX = localTrimStart * trackWidth
                        let trimEndX = localTrimEnd * trackWidth
                        let playableWidth = trimEndX - trimStartX

                        // Normalize currentPosition to the trimmed range
                        let normalizedPosition = max(0, min(1, (currentPosition - localTrimStart) / (localTrimEnd - localTrimStart)))
                        let handleX = trimStartX + (normalizedPosition * playableWidth)

                        ZStack(alignment: .leading) {
                            // Background track (full width, grayed out)
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: trackWidth, height: 4)
                                .cornerRadius(2)

                            // Playable range track
                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: playableWidth, height: 4)
                                .position(x: trimStartX + playableWidth / 2, y: 7)
                                .cornerRadius(2)

                            // Played portion
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: max(0, handleX - trimStartX), height: 4)
                                .position(x: trimStartX + max(0, handleX - trimStartX) / 2, y: 10)
                                .cornerRadius(2)

                            // Trim Start Handle (triangle pointing right)
                            TriangleShape(direction: .right)
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                                .overlay(TriangleShape(direction: .right).stroke(Color.blue, lineWidth: 2))
                                .position(x: trimStartX, y: 10)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let rawValue = value.location.x / trackWidth
                                            let newValue = min(max(0, rawValue), localTrimEnd - 0.01)
                                            localTrimStart = newValue

                                            // Generate preview frame at new trim position
                                            generatePreviewFrame(at: newValue)

                                            // Update currentPosition if it's now outside the trim range
                                            if currentPosition < newValue {
                                                currentPosition = newValue
                                                if let player = player {
                                                    let seekTime = CMTime(seconds: asset.duration * newValue, preferredTimescale: 600)
                                                    player.seek(to: seekTime)
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            previewImage = nil
                                            asset.trimStartTime = localTrimStart
                                            try? asset.managedObjectContext?.save()
                                        }
                                )

                            // Trim End Handle (triangle pointing left)
                            TriangleShape(direction: .left)
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                                .overlay(TriangleShape(direction: .left).stroke(Color.blue, lineWidth: 2))
                                .position(x: trimEndX, y: 10)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let rawValue = value.location.x / trackWidth
                                            let newValue = min(max(localTrimStart + 0.01, rawValue), 1.0)
                                            localTrimEnd = newValue

                                            // Generate preview frame at new trim position
                                            generatePreviewFrame(at: newValue)

                                            // Update currentPosition if it's now outside the trim range
                                            if currentPosition > newValue {
                                                currentPosition = newValue
                                                if let player = player {
                                                    let seekTime = CMTime(seconds: asset.duration * newValue, preferredTimescale: 600)
                                                    player.seek(to: seekTime)
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            previewImage = nil
                                            asset.trimEndTime = localTrimEnd
                                            try? asset.managedObjectContext?.save()
                                        }
                                )

                            // Playhead handle
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                                .position(x: handleX, y: 10)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            // Constrain dragging to trim range
                                            let rawPosition = value.location.x / trackWidth
                                            let constrainedPosition = max(localTrimStart, min(localTrimEnd, rawPosition))
                                            currentPosition = constrainedPosition

                                            // Seek video to new position
                                            if let player = player {
                                                let seekTime = CMTime(seconds: asset.duration * constrainedPosition, preferredTimescale: 600)
                                                player.seek(to: seekTime)
                                            }
                                        }
                                )
                        }
                        .frame(width: trackWidth, height: 14)
                    }
                    .frame(height: 14)
                    .disabled(isFlaggedForDeletion)

                    // Duration
                    Text(formatTime(asset.duration * localTrimEnd))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            loadPlayer()
            if shouldAutoPlay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startPlayback()
                }
            }
        }
        .onDisappear {
            removeTimeObserver()
            player?.pause()
        }
        .onChange(of: asset.selectedLUTId) { newLUTId in
            print("🎨 CleanVideoPlayerView: LUT selection changed for \(asset.fileName ?? "unknown")")
            print("   New LUT ID: \(newLUTId ?? "nil")")
            print("   Reloading player with new LUT...")
            loadPlayer()
        }
        .onChange(of: asset.id) { _ in
            // Reload player when asset changes
            removeTimeObserver()
            player?.pause()
            isPlaying = false
            loadPlayer()
        }
        .onChange(of: scrubPosition) { position in
            // Generate preview when scrubbing from sidebar
            if let position = position {
                generatePreviewFrame(at: position)
            } else {
                // Clear preview when scrubbing ends
                previewImage = nil
            }
        }
        .onChange(of: localTrimStart) { newStart in
            // Push playback position inside bounds if needed
            if currentPosition < newStart {
                currentPosition = newStart
                if let player = player {
                    let seekTime = CMTime(seconds: asset.duration * newStart, preferredTimescale: 600)
                    player.seek(to: seekTime)
                }
            }
        }
        .onChange(of: localTrimEnd) { newEnd in
            // Push playback position inside bounds if needed
            if currentPosition > newEnd {
                currentPosition = newEnd
                if let player = player {
                    let seekTime = CMTime(seconds: asset.duration * newEnd, preferredTimescale: 600)
                    player.seek(to: seekTime)
                }
            }

            // Recreate boundary observer with new end point
            if isPlaying {
                setupBoundaryObserver()
            }
        }
        .background(
            // Hidden buttons for keyboard shortcuts
            HStack {
                // Frame skimming
                Button("") { skimBackwardOneFrame() }
                    .keyboardShortcut(.leftArrow, modifiers: .shift)
                    .hidden()

                Button("") { skimForwardOneFrame() }
                    .keyboardShortcut(.rightArrow, modifiers: .shift)
                    .hidden()

                // Trim points
                Button("") { setInPoint() }
                    .keyboardShortcut(KeyEquivalent(preferences.hotkeySetInPoint.lowercased().first ?? "a"), modifiers: [])
                    .hidden()

                Button("") { setOutPoint() }
                    .keyboardShortcut(KeyEquivalent(preferences.hotkeySetOutPoint.lowercased().first ?? "s"), modifiers: [])
                    .hidden()

                // Mark for deletion
                Button("") { toggleDeletion() }
                    .keyboardShortcut(KeyEquivalent(preferences.hotkeyToggleDeletion.lowercased().first ?? "d"), modifiers: [])
                    .hidden()

                // Reset trim points
                Button("") { resetTrimPoints() }
                    .keyboardShortcut(KeyEquivalent(preferences.hotkeyResetTrimPoints.lowercased().first ?? "f"), modifiers: [])
                    .hidden()
            }
        )
    }

    // MARK: - Computed Properties

    private var preserveText: String {
        let workflowMode = UserPreferences.shared.workflowMode
        return workflowMode == .cullInPlace ? "Preserve" : "Import"
    }

    private var deleteText: String {
        let workflowMode = UserPreferences.shared.workflowMode
        return workflowMode == .cullInPlace ? "Delete" : "Skip"
    }

    // MARK: - Frame Skimming

    private func skimForwardOneFrame() {
        guard let player = player else { return }

        // Calculate one frame duration based on video frame rate
        let frameDuration = 1.0 / (asset.frameRate > 0 ? asset.frameRate : 30.0)
        let frameDurationNormalized = frameDuration / asset.duration

        // Move forward by one frame
        let newPosition = min(localTrimEnd, currentPosition + frameDurationNormalized)
        currentPosition = newPosition

        let seekTime = CMTime(seconds: asset.duration * newPosition, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // Generate preview frame
        generatePreviewFrame(at: newPosition)
    }

    private func skimBackwardOneFrame() {
        guard let player = player else { return }

        // Calculate one frame duration based on video frame rate
        let frameDuration = 1.0 / (asset.frameRate > 0 ? asset.frameRate : 30.0)
        let frameDurationNormalized = frameDuration / asset.duration

        // Move backward by one frame
        let newPosition = max(localTrimStart, currentPosition - frameDurationNormalized)
        currentPosition = newPosition

        let seekTime = CMTime(seconds: asset.duration * newPosition, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // Generate preview frame
        generatePreviewFrame(at: newPosition)
    }

    // MARK: - Trim Point Controls

    private func setInPoint() {
        // Set trim start to current playhead position
        localTrimStart = currentPosition
        asset.trimStartTime = currentPosition
        try? asset.managedObjectContext?.save()

        print("✂️ In point set at \(formatTime(currentPosition * asset.duration))")
    }

    private func setOutPoint() {
        // Set trim end to current playhead position
        localTrimEnd = currentPosition
        asset.trimEndTime = currentPosition
        try? asset.managedObjectContext?.save()

        // Stop playback if playing
        if isPlaying {
            player?.pause()
            isPlaying = false
        }

        print("✂️ Out point set at \(formatTime(currentPosition * asset.duration))")
    }

    private func toggleDeletion() {
        // Toggle deletion flag
        asset.isFlaggedForDeletion.toggle()
        try? asset.managedObjectContext?.save()

        print(asset.isFlaggedForDeletion ? "🗑️ Marked for deletion" : "✅ Unmarked for deletion")
    }

    private func resetTrimPoints() {
        // Reset trim points to full video
        localTrimStart = 0.0
        localTrimEnd = 1.0
        asset.trimStartTime = 0.0
        asset.trimEndTime = 1.0
        try? asset.managedObjectContext?.save()

        // Seek to start
        currentPosition = 0.0
        if let player = player {
            player.seek(to: .zero)
        }

        print("🔄 Trim points reset to full duration")
    }

    private func loadPlayer() {
        guard let url = asset.fileURL else { return }

        print("🎬 loadPlayer() called for: \(asset.fileName ?? "unknown")")
        print("   selectedLUTId: \(asset.selectedLUTId ?? "nil")")

        // Remove existing time observer before creating new player
        removeTimeObserver()

        _ = url.startAccessingSecurityScopedResource()

        // Create AVAsset and PlayerItem for composition
        let avAsset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: avAsset)

        // Apply video composition with LUT BEFORE creating the player
        // This ensures the composition is ready when playback starts
        Task {
            if let composition = await createLUTVideoComposition(for: avAsset, lutId: asset.selectedLUTId) {
                await MainActor.run {
                    playerItem.videoComposition = composition
                    print("✅ Video composition with LUT applied for \(asset.fileName ?? "unknown")")
                }
            } else {
                print("⚠️ No video composition created for \(asset.fileName ?? "unknown") - LUT ID: \(asset.selectedLUTId ?? "nil")")
            }

            // Create player AFTER composition is applied
            await MainActor.run {
                let newPlayer = AVPlayer(playerItem: playerItem)

                // Enable automatic waiting to minimize stalls for smoother playback
                newPlayer.automaticallyWaitsToMinimizeStalling = true

                // Use automatic resource allocation for better performance
                if #available(macOS 12.0, *) {
                    newPlayer.audiovisualBackgroundPlaybackPolicy = .automatic
                }

                self.player = newPlayer
                print("✅ Player created with composition for \(asset.fileName ?? "unknown")")
            }
        }

        // Create hardware-accelerated CIContext for LUT processing
        if ciContext == nil {
            ciContext = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .useSoftwareRenderer: false, // Force GPU rendering
                .priorityRequestLow: false // High priority
            ])
        }

        // Generate thumbnail and set up image generator for scrubbing
        Task {
            let avAsset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 800, height: 600)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            await MainActor.run {
                self.imageGenerator = generator
            }

            do {
                let time = CMTime(seconds: 1.0, preferredTimescale: 600)
                // Use ThumbnailService to throttle concurrent generations
                let cgImage = try await ThumbnailService.shared.generateThumbnail(
                    for: avAsset,
                    at: time,
                    maxSize: CGSize(width: 400, height: 300)
                )
                let finalImage = await applyLUTToImage(cgImage: cgImage)

                await MainActor.run {
                    self.thumbnail = finalImage
                }
            } catch {
                print("Failed to generate thumbnail: \(error)")
            }
        }
    }

    private func generatePreviewFrame(at normalizedTime: Double) {
        guard let generator = imageGenerator else { return }

        let timeInSeconds = normalizedTime * asset.duration
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)

        Task {
            do {
                // Use ThumbnailService to throttle concurrent generations
                guard let avAsset = (generator.asset as? AVAsset) ?? generator.asset as? AVURLAsset else {
                    print("Failed to get AVAsset from generator")
                    return
                }
                let cgImage = try await ThumbnailService.shared.generateThumbnail(
                    for: avAsset,
                    at: time,
                    maxSize: CGSize(width: 400, height: 300)
                )
                let finalImage = await applyLUTToImage(cgImage: cgImage)

                await MainActor.run {
                    self.previewImage = finalImage
                }
            } catch {
                print("Failed to generate preview frame: \(error)")
            }
        }
    }

    private func applyLUTToImage(cgImage: CGImage) async -> NSImage {
        guard let lutIdString = asset.selectedLUTId,
              !lutIdString.isEmpty,
              let lutId = UUID(uuidString: lutIdString),
              let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == lutId }),
              let context = ciContext else {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        let ciImage = CIImage(cgImage: cgImage)

        if let lutAppliedImage = lutManager.applyLUT(selectedLUT, to: ciImage) {
            // Use hardware-accelerated context for GPU rendering
            if let outputCGImage = context.createCGImage(lutAppliedImage, from: lutAppliedImage.extent) {
                return NSImage(cgImage: outputCGImage, size: NSSize(width: outputCGImage.width, height: outputCGImage.height))
            }
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // Create AVVideoComposition with LUT filter for playback
    private func createLUTVideoComposition(for avAsset: AVAsset, lutId: String?) async -> AVVideoComposition? {
        print("🎨 Creating video composition with LUT for playback")
        print("   LUT ID: \(lutId ?? "nil")")
        print("   Available LUTs count: \(lutManager.availableLUTs.count)")

        // No LUT selected - return nil (use default rendering)
        guard let lutIdString = lutId,
              !lutIdString.isEmpty else {
            print("   ❌ LUT ID is nil or empty")
            return nil
        }

        guard let lutUUID = UUID(uuidString: lutIdString) else {
            print("   ❌ Failed to parse LUT ID as UUID: \(lutIdString)")
            return nil
        }

        guard let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == lutUUID }) else {
            print("   ❌ LUT not found in available LUTs. Looking for ID: \(lutUUID)")
            print("   Available LUT IDs: \(lutManager.availableLUTs.map { $0.id })")
            return nil
        }

        print("   ✅ Found LUT: \(selectedLUT.name)")

        // Create LUT filter (without input image)
        guard let lutFilter = lutManager.createLUTFilter(for: selectedLUT) else {
            print("   ❌ Failed to create LUT filter")
            return nil
        }

        print("   ✅ LUT filter created successfully")

        // Get video track for composition
        guard let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first else {
            print("   ❌ No video track found")
            return nil
        }

        let naturalSize = try? await videoTrack.load(.naturalSize)
        print("   ✅ Video track loaded: size=\(naturalSize ?? .zero)")

        // Create video composition with custom compositor
        let composition = AVMutableVideoComposition(asset: avAsset) { request in
            // Get source frame
            let sourceImage = request.sourceImage.clampedToExtent()

            // Apply LUT filter
            lutFilter.setValue(sourceImage, forKey: kCIInputImageKey)

            // Get output image
            if let outputImage = lutFilter.outputImage {
                // Crop to original extent to avoid edge artifacts
                let croppedImage = outputImage.cropped(to: request.sourceImage.extent)
                request.finish(with: croppedImage, context: nil)
            } else {
                // Fallback to source if LUT fails
                request.finish(with: sourceImage, context: nil)
            }
        }

        // Configure composition properties
        if let size = naturalSize {
            composition.renderSize = size
        }
        composition.frameDuration = CMTime(value: 1, timescale: 30) // 30fps

        print("   ✅ Video composition created successfully")
        return composition
    }

    private func startPlayback() {
        guard let player = player else { return }

        // Set up observers FIRST
        setupTimeObserver()
        setupBoundaryObserver()

        // Then seek to trim start with precise tolerances
        let startTime = CMTime(seconds: asset.duration * localTrimStart, preferredTimescale: 600)
        player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            guard finished else { return }

            Task { @MainActor in
                // Only start playing if seek completed successfully
                self.isPlaying = true
                player.play()
            }
        }
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        removeTimeObserver()

        // More efficient observer - only updates position, doesn't check bounds every time
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let duration = asset.duration
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let currentSeconds = CMTimeGetSeconds(time)
            let normalizedPosition = currentSeconds / duration

            Task { @MainActor in
                self.currentPosition = normalizedPosition
            }
        }

        // Track which player owns this observer
        observerPlayer = player
    }

    private func setupBoundaryObserver() {
        guard let player = player else { return }

        // Remove any existing boundary observer
        if let boundaryObs = self.boundaryObserver {
            player.removeTimeObserver(boundaryObs)
        }

        // Create boundary time for trim end
        let endTime = CMTime(seconds: asset.duration * localTrimEnd, preferredTimescale: 600)

        // Capture values for the closure
        let duration = asset.duration
        let trimStart = localTrimStart
        let videoEndedCallback = onVideoEnded

        // Add boundary observer - fires exactly when we hit the end time (much more efficient)
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
            Task { @MainActor in
                player.pause()
                self.isPlaying = false

                // Seek back to trim start for next play
                let startTime = CMTime(seconds: duration * trimStart, preferredTimescale: 600)
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                self.currentPosition = trimStart

                // Notify that video ended
                videoEndedCallback?()
            }
        }
    }

    private func removeTimeObserver() {
        // Remove periodic time observer
        if let observer = timeObserver {
            // Try to remove from the current player first (if it exists)
            if let currentPlayer = player {
                currentPlayer.removeTimeObserver(observer)
            } else if let ownerPlayer = observerPlayer {
                // Fallback to owner player if current player is nil
                ownerPlayer.removeTimeObserver(observer)
            }
            timeObserver = nil
        }

        // Remove boundary observer
        if let boundaryObs = boundaryObserver {
            if let currentPlayer = player {
                currentPlayer.removeTimeObserver(boundaryObs)
            } else if let ownerPlayer = observerPlayer {
                ownerPlayer.removeTimeObserver(boundaryObs)
            }
            boundaryObserver = nil
        }

        // Clear player reference
        observerPlayer = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Optimized Video Player View (Hardware Accelerated)
struct OptimizedVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        // Enable hardware acceleration for smoother playback
        playerLayer.drawsAsynchronously = true

        view.layer = playerLayer
        view.wantsLayer = true

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
}

// MARK: - Thumbnail Card View
struct ThumbnailCardView: View {
    @ObservedObject var asset: ManagedVideoAsset
    let isSelected: Bool
    let onTap: () -> Void
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail image
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 90)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 160, height: 90)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                }

                // Duration overlay
                if asset.duration > 0 {
                    Text(formatDuration(asset.duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(4)
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )

            // Metadata overlays
            HStack(spacing: 4) {
                // Flagged indicator
                if asset.isFlaggedForDeletion {
                    Image(systemName: "trash.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                // Rating
                if asset.userRating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<Int(asset.userRating), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Spacer()

                // Resolution
                if asset.videoWidth > 0 && asset.videoHeight > 0 {
                    Text("\(Int(asset.videoWidth))×\(Int(asset.videoHeight))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Filename
            Text(asset.fileName ?? "Unknown")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 160)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .frame(width: 160)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 2 : 1)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            generateThumbnail()
        }
    }

    private func generateThumbnail() {
        guard let fileURL = asset.fileURL else { return }

        Task {
            let avAsset = AVAsset(url: fileURL)

            do {
                // Use ThumbnailService to throttle concurrent generations
                let cgImage = try await ThumbnailService.shared.generateThumbnail(
                    for: avAsset,
                    at: .zero,
                    maxSize: CGSize(width: 320, height: 180)
                )
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 180))

                await MainActor.run {
                    self.thumbnail = nsImage
                }
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
