//
//  PlayerView.swift
//  VideoCullingApp
//

import SwiftUI
import AVKit
import AVFoundation
import CoreImage

struct PlayerView: View {
    @ObservedObject var asset: ManagedVideoAsset
    @Binding var localTrimStart: Double
    @Binding var localTrimEnd: Double
    var onVideoEnded: (() -> Void)?
    var shouldAutoPlay: Bool = false
    var isSelected: Bool = false

    @State private var player: AVPlayer?
    @State private var thumbnail: NSImage?
    @State private var isPlaying = false
    @State private var previewImage: NSImage?
    @State private var imageGenerator: AVAssetImageGenerator?
    @State private var timeObserver: Any?
    @State private var boundaryObserver: Any?
    @State private var observerPlayer: AVPlayer? // Track which player owns the observer
    @State private var currentPosition: Double = 0.0 // Normalized position (0.0 to 1.0)
    @ObservedObject private var lutManager = LUTManager.shared
    @ObservedObject private var preferences = UserPreferences.shared
    private let hotkeyManager = HotkeyManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Video Preview Area
            GeometryReader { geometry in
                ZStack {
                    if isPlaying, let player = player {
                        // Show custom video player without controls
                        CustomVideoPlayerView(player: player)
                            .frame(height: 220)
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                                player.seek(to: .zero)
                            }
                    } else {
                        // Show preview image (when scrubbing) or thumbnail
                        if let previewImage = previewImage {
                            Image(nsImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 220)
                                .clipped()
                        } else if let thumbnail = thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 220)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 220)
                        }
                    }

                    // Toggle Gallery Mode button in bottom-right corner (always visible)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                // Cleanup before toggling
                                if isPlaying {
                                    player?.pause()
                                    isPlaying = false
                                }
                                removeTimeObserver()

                                // Toggle between vertical and horizontal mode
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
                            .padding(8)
                        }
                    }

                    // Grey overlay when flagged for deletion
                    if asset.isFlaggedForDeletion {
                        Rectangle()
                            .fill(Color.gray.opacity(0.7))
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 220)
            .cornerRadius(8)

            // Playback Controls
            HStack(spacing: 12) {
                // Play/Stop Button
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
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .if(isPlaying) { view in
                    // Only add keyboard shortcut to the currently playing video
                    view.keyboardShortcut(.space, modifiers: [])
                }
                .accessibilityIdentifier("playPauseButton")
                .disabled(asset.isFlaggedForDeletion)

                // Current Time
                Text(formatTime(currentPosition * asset.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Combined Position Slider with Trim Markers
                GeometryReader { geometry in
                    let trackWidth = geometry.size.width
                    let trimStartX = localTrimStart * trackWidth
                    let trimEndX = localTrimEnd * trackWidth
                    let playableWidth = trimEndX - trimStartX

                    // Normalize currentPosition to the trimmed range
                    let normalizedPosition = max(0, min(1, (currentPosition - localTrimStart) / (localTrimEnd - localTrimStart)))
                    let handleX = trimStartX + (normalizedPosition * playableWidth)

                    ZStack(alignment: .leading) {
                        // Background track (full width, grayed out) - make more subtle
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: trackWidth, height: 4)
                            .cornerRadius(2)

                        // Playable range track - make more prominent
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: playableWidth, height: 4)
                            .position(x: trimStartX + playableWidth / 2, y: 10)
                            .cornerRadius(2)

                        // Played portion - keep strong blue
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: max(0, handleX - trimStartX), height: 4)
                            .position(x: trimStartX + max(0, handleX - trimStartX) / 2, y: 10)
                            .cornerRadius(2)

                        // Add visual indicator if playhead is outside trim bounds (should never happen, but defensive)
                        if currentPosition < localTrimStart || currentPosition > localTrimEnd {
                            // Red warning indicator
                            Rectangle()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: 2, height: 20)
                                .position(x: handleX, y: 10)
                        }

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
                    .frame(width: trackWidth, height: 20)
                }
                .frame(height: 20)

                // Duration
                Text(formatTime(asset.duration * localTrimEnd))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 4)

            // Trim time labels
            HStack {
                Text(formatTime(localTrimStart * asset.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(localTrimEnd * asset.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            // Audio Waveform
            WaveformView(
                asset: asset,
                trimStart: $localTrimStart,
                trimEnd: $localTrimEnd
            )

            // Flag for Deletion Toggle (below waveform)
            Toggle("Flag for Deletion / Do not import", isOn: $asset.isFlaggedForDeletion)
                .tint(.red)
                .onChange(of: asset.isFlaggedForDeletion) { newValue in
                    if let context = asset.managedObjectContext {
                        do {
                            try context.save()
                            print("✅ Saved deletion flag: \(newValue) for \(asset.fileName ?? "unknown")")
                        } catch {
                            print("❌ Failed to save deletion flag: \(error.localizedDescription)")
                        }
                    }
                }
        }
        .onAppear {
            loadThumbnailAndPlayer()

            // Listen for LUT preference learning events
            NotificationCenter.default.addObserver(
                forName: LUTManager.lutPreferenceLearnedNotification,
                object: nil,
                queue: .main
            ) { [weak asset] notification in
                guard let asset = asset,
                      let userInfo = notification.userInfo,
                      let learnedGamma = userInfo["gamma"] as? String,
                      let learnedColorSpace = userInfo["colorSpace"] as? String,
                      let learnedLUTId = userInfo["lutId"] as? String else {
                    return
                }

                // Check if this asset matches the learned camera metadata
                let assetGamma = asset.captureGamma?.lowercased() ?? ""
                let assetColorSpace = asset.captureColorPrimaries?.lowercased() ?? ""

                // Normalize for comparison (same as LUTAutoMapper)
                let normalizedAssetGamma = LUTAutoMapper.normalizeForMatching(assetGamma)
                let normalizedAssetColorSpace = LUTAutoMapper.normalizeForMatching(assetColorSpace)

                if normalizedAssetGamma == learnedGamma && normalizedAssetColorSpace == learnedColorSpace {
                    print("🎓 PlayerView: LUT learning notification received for matching asset")
                    print("   Asset: \(asset.fileName ?? "unknown")")
                    print("   Gamma: \(learnedGamma), ColorSpace: \(learnedColorSpace)")
                    print("   New LUT ID: \(learnedLUTId)")

                    // Update asset's selectedLUTId (this will trigger onChange)
                    Task { @MainActor in
                        asset.selectedLUTId = learnedLUTId

                        // Save Core Data context
                        if let context = asset.managedObjectContext {
                            do {
                                try context.save()
                                print("   ✅ Asset LUT updated and saved")
                            } catch {
                                print("   ❌ Failed to save Core Data: \(error)")
                            }
                        }
                    }
                }
            }

            // Set up hotkeys if this is the selected row
            if isSelected {
                setupHotkeyCallbacks()
            }
        }
        .onDisappear {
            // Clear hotkey callbacks when view disappears
            if isSelected {
                clearHotkeyCallbacks()
            }
            removeTimeObserver()
        }
        .onChange(of: asset.selectedLUTId) { newLUTId in
            // Regenerate thumbnail when LUT changes
            print("🎨 PlayerView: LUT selection changed for \(asset.fileName ?? "unknown")")
            print("   New LUT ID: \(newLUTId ?? "nil")")
            print("   Updating video composition and thumbnail with new LUT...")

            // Stop playback if playing
            if isPlaying {
                player?.pause()
                isPlaying = false
            }

            // Update video composition for playback
            Task {
                guard let player = player,
                      let playerItem = player.currentItem,
                      let avAsset = playerItem.asset as? AVAsset else {
                    print("   ⚠️ No player item found, reloading player...")
                    loadThumbnailAndPlayer()
                    return
                }

                // Create new video composition with updated LUT
                if let composition = await createLUTVideoComposition(for: avAsset, lutId: newLUTId) {
                    await MainActor.run {
                        playerItem.videoComposition = composition
                        print("   ✅ Video composition updated with new LUT")
                    }
                } else {
                    // No LUT selected - remove video composition
                    await MainActor.run {
                        playerItem.videoComposition = nil
                        print("   ✅ Video composition removed (no LUT)")
                    }
                }

                // Regenerate thumbnail with new LUT
                if let imageGenerator = imageGenerator {
                    do {
                        let time = CMTime(seconds: asset.duration * currentPosition, preferredTimescale: 600)
                        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                        let finalImage = await applyLUTToImage(cgImage: cgImage)

                        await MainActor.run {
                            self.thumbnail = finalImage
                            print("   ✅ Thumbnail updated with new LUT")
                        }
                    } catch {
                        print("   ❌ Failed to regenerate thumbnail: \(error)")
                    }
                }
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
        }
        .onChange(of: isSelected) { newSelection in
            // Update hotkeys when selection changes
            if newSelection {
                setupHotkeyCallbacks()
            } else {
                clearHotkeyCallbacks()
            }
        }
        .background(
            // Hidden buttons for keyboard shortcuts
            // Only active when this video is playing
            HStack {
                if isPlaying {
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
            }
        )
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

    // MARK: - Hotkey Callbacks

    private func setupHotkeyCallbacks() {
        // Capture necessary values to avoid capturing self
        let asset = self.asset
        let player = self.player

        // Play/Pause toggle
        hotkeyManager.onTogglePlayPause = {
            Task { @MainActor in
                // Note: Since PlayerView is a struct, we can't directly modify state from closure
                player?.play()
            }
        }

        // Set in point (trim start)
        hotkeyManager.onSetInPoint = {
            Task { @MainActor in
                // Access asset directly to set trim point
                if let player = player {
                    let currentTime = CMTimeGetSeconds(player.currentTime())
                    let normalizedTime = currentTime / asset.duration
                    asset.trimStartTime = normalizedTime
                    try? asset.managedObjectContext?.save()
                    print("✂️ In point set")
                }
            }
        }

        // Set out point (trim end)
        hotkeyManager.onSetOutPoint = {
            Task { @MainActor in
                if let player = player {
                    let currentTime = CMTimeGetSeconds(player.currentTime())
                    let normalizedTime = currentTime / asset.duration
                    asset.trimEndTime = normalizedTime
                    try? asset.managedObjectContext?.save()
                    player.pause()
                    print("✂️ Out point set")
                }
            }
        }
    }

    private func clearHotkeyCallbacks() {
        // Clear only the callbacks this PlayerView owns
        // Navigation and deletion are handled by GalleryView
        hotkeyManager.onTogglePlayPause = nil
        hotkeyManager.onSetInPoint = nil
        hotkeyManager.onSetOutPoint = nil
    }

    private func loadThumbnailAndPlayer() {
        guard let url = asset.fileURL else {
            print("Invalid file path for asset: \(asset.fileName ?? "unknown")")
            return
        }

        // Remove existing time observer before creating new player
        removeTimeObserver()

        // Create player - always create it, security scope is handled by the file system
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

            // Generate thumbnail and set up image generator
            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 300)
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

                // Apply LUT if selected
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
        print("🔍 generatePreviewFrame called with normalizedTime: \(normalizedTime)")

        guard let generator = imageGenerator else {
            print("❌ imageGenerator is nil")
            return
        }

        print("✅ imageGenerator exists")

        let timeInSeconds = normalizedTime * asset.duration
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)

        print("🎬 Generating frame at time: \(timeInSeconds)s")

        Task {
            do {
                // Use ThumbnailService to throttle concurrent generations
                guard let avAsset = (generator.asset as? AVAsset) ?? generator.asset as? AVURLAsset else {
                    print("❌ Could not get AVAsset from generator")
                    return
                }
                let cgImage = try await ThumbnailService.shared.generateThumbnail(
                    for: avAsset,
                    at: time,
                    maxSize: CGSize(width: 400, height: 300)
                )
                print("✅ Generated cgImage for time: \(timeInSeconds)s")

                // Apply LUT if selected
                let finalImage = await applyLUTToImage(cgImage: cgImage)

                await MainActor.run {
                    self.previewImage = finalImage
                    print("✅ Set previewImage on MainActor")
                }
            } catch {
                print("❌ Failed to generate preview frame: \(error)")
            }
        }
    }

    // Helper function to apply LUT to a CGImage
    private func applyLUTToImage(cgImage: CGImage) async -> NSImage {
        print("🎨 applyLUTToImage called for asset: \(asset.fileName ?? "unknown")")
        print("   selectedLUTId: \(asset.selectedLUTId ?? "nil")")

        // Get the selected LUT
        guard let lutIdString = asset.selectedLUTId,
              !lutIdString.isEmpty,
              let lutId = UUID(uuidString: lutIdString),
              let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == lutId }) else {
            print("   ❌ No LUT selected or LUT not found, returning original image")
            // No LUT selected, return original image
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        print("   ✅ Found LUT: \(selectedLUT.name)")

        // Convert CGImage to CIImage
        let ciImage = CIImage(cgImage: cgImage)
        print("   📷 Converting CGImage to CIImage, size: \(ciImage.extent)")

        // Apply LUT
        if let lutAppliedImage = lutManager.applyLUT(selectedLUT, to: ciImage) {
            print("   ✅ LUT applied successfully")
            // Convert CIImage back to NSImage
            let context = CIContext()
            if let outputCGImage = context.createCGImage(lutAppliedImage, from: lutAppliedImage.extent) {
                print("   ✅ Converted back to NSImage")
                return NSImage(cgImage: outputCGImage, size: NSSize(width: outputCGImage.width, height: outputCGImage.height))
            } else {
                print("   ❌ Failed to convert CIImage back to CGImage")
            }
        } else {
            print("   ❌ LUT application failed")
        }

        // If LUT application failed, return original image
        print("   ⚠️ Returning original image (LUT application failed)")
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // Create AVVideoComposition with LUT filter for playback
    private func createLUTVideoComposition(for avAsset: AVAsset, lutId: String?) async -> AVVideoComposition? {
        print("🎨 Creating video composition with LUT for playback")
        print("   LUT ID: \(lutId ?? "nil")")

        // No LUT selected - return nil (use default rendering)
        guard let lutIdString = lutId,
              !lutIdString.isEmpty,
              let lutUUID = UUID(uuidString: lutIdString),
              let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == lutUUID }) else {
            print("   ❌ No LUT selected for video composition")
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
        let preferredTransform = try? await videoTrack.load(.preferredTransform)

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

    // MARK: - Trim-Aware Playback
    //
    // Playback is constrained to the trim range (localTrimStart to localTrimEnd):
    // 1. Playback always starts at trim start position
    // 2. Time observer monitors playback and stops at trim end
    // 3. Boundary observer provides precise stop at exact trim end time
    // 4. Playhead dragging is constrained to trim range only
    // 5. Trim marker changes push playhead inside bounds if needed

    private func startPlayback() {
        guard let player = player else { return }

        // Set up observers FIRST
        setupTimeObserver()
        setupBoundaryObserver()

        // Then seek to trim start with precise tolerances
        let startTime = CMTime(seconds: asset.duration * localTrimStart, preferredTimescale: 600)
        player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished else { return }

            Task { @MainActor in
                // Only start playing if seek completed successfully
                self.isPlaying = true
                player.play()
            }
        }
    }

    private func seekToTrimPosition(_ normalizedTime: Double) {
        guard let player = player else { return }

        let time = CMTime(seconds: asset.duration * normalizedTime, preferredTimescale: 600)
        player.seek(to: time)
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        // Remove existing observer
        removeTimeObserver()

        // Add periodic observer - ONLY update UI, don't control playback
        let interval = CMTime(seconds: 0.033, preferredTimescale: 600) // ~30fps update rate
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            let currentSeconds = CMTimeGetSeconds(time)
            let normalizedPosition = currentSeconds / self.asset.duration

            // Update current position for UI ONLY
            Task { @MainActor in
                self.currentPosition = normalizedPosition
            }

            // Check if we've reached or passed the trim end
            let endTime = self.asset.duration * self.localTrimEnd
            if currentSeconds >= endTime - 0.05 { // Stop slightly before end to avoid overshoot
                Task { @MainActor in
                    player.pause()
                    self.isPlaying = false
                    // Seek back to trim start for next play
                    let startTime = CMTime(seconds: self.asset.duration * self.localTrimStart, preferredTimescale: 600)
                    player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    self.currentPosition = self.localTrimStart
                }
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

        // Add boundary observer - fires exactly when we hit the end time
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) { [weak self] in
            guard let self = self else { return }

            Task { @MainActor in
                player.pause()
                self.isPlaying = false

                // Seek back to trim start for next play
                let startTime = CMTime(seconds: self.asset.duration * self.localTrimStart, preferredTimescale: 600)
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                self.currentPosition = self.localTrimStart
            }
        }
    }

    private func removeTimeObserver() {
        guard let observer = timeObserver else { return }

        // Try to remove from the current player first (if it exists)
        if let currentPlayer = player {
            currentPlayer.removeTimeObserver(observer)

            // Also remove boundary observer
            if let boundaryObs = boundaryObserver {
                currentPlayer.removeTimeObserver(boundaryObs)
                boundaryObserver = nil
            }
        } else if let ownerPlayer = observerPlayer {
            // Fallback to owner player if current player is nil
            ownerPlayer.removeTimeObserver(observer)

            if let boundaryObs = boundaryObserver {
                ownerPlayer.removeTimeObserver(boundaryObs)
                boundaryObserver = nil
            }
        }

        // Clear references
        timeObserver = nil
        observerPlayer = nil
    }
}

// MARK: - Trim Range Slider
struct TrimRangeSlider: View {
    @Binding var start: Double
    @Binding var end: Double
    let duration: Double
    var onScrub: ((Double) -> Void)? = nil
    var onScrubEnd: (() -> Void)? = nil

    @State private var localStart: Double = 0
    @State private var localEnd: Double = 1
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                let trackWidth = geometry.size.width
                let startX = localStart * trackWidth
                let endX = localEnd * trackWidth

                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: trackWidth, height: 6)
                        .cornerRadius(3)

                    // Selected range - spans from start handle center to end handle center
                    ZStack {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: max(0, endX - startX), height: 6)
                            .cornerRadius(3)

                        // Show trimmed duration text if trimmed
                        if localStart > 0.001 || localEnd < 0.999 {
                            Text(formatTrimmedDuration(duration: duration, start: localStart, end: localEnd))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
                        }
                    }
                    .position(x: startX + (endX - startX) / 2, y: 10)

                    // Start handle (triangle pointing right)
                    TriangleShape(direction: .right)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(TriangleShape(direction: .right).stroke(Color.blue, lineWidth: 2))
                        .position(x: startX, y: 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingStart = true
                                    let rawValue = value.location.x / trackWidth
                                    var newValue = min(max(0, rawValue), localEnd - 0.01)

                                    // Apply precision mode when SHIFT is held
                                    if NSEvent.modifierFlags.contains(.shift) {
                                        let frameCount = duration * 30.0 // Assume 30fps for precision
                                        let frameNumber = round(newValue * frameCount)
                                        newValue = frameNumber / frameCount
                                    }

                                    localStart = newValue
                                    onScrub?(newValue)
                                }
                                .onEnded { _ in
                                    isDraggingStart = false
                                    start = localStart
                                    onScrubEnd?()
                                }
                        )

                    // End handle (triangle pointing left)
                    TriangleShape(direction: .left)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(TriangleShape(direction: .left).stroke(Color.blue, lineWidth: 2))
                        .position(x: endX, y: 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingEnd = true
                                    let rawValue = value.location.x / trackWidth
                                    var newValue = min(max(localStart + 0.01, rawValue), 1.0)

                                    // Apply precision mode when SHIFT is held
                                    if NSEvent.modifierFlags.contains(.shift) {
                                        let frameCount = duration * 30.0 // Assume 30fps for precision
                                        let frameNumber = round(newValue * frameCount)
                                        newValue = frameNumber / frameCount
                                    }

                                    localEnd = newValue
                                    onScrub?(newValue)
                                }
                                .onEnded { _ in
                                    isDraggingEnd = false
                                    end = localEnd
                                    onScrubEnd?()
                                }
                        )
                }
                .frame(width: trackWidth, height: 20)
            }
            .frame(height: 20)
            .onAppear {
                localStart = start
                localEnd = end
            }
            .onChange(of: start) { newValue in
                if !isDraggingStart {
                    localStart = newValue
                }
            }
            .onChange(of: end) { newValue in
                if !isDraggingEnd {
                    localEnd = newValue
                }
            }

            // Time labels
            HStack {
                Text(formatTime(localStart * duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(localEnd * duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatTrimmedDuration(duration: Double, start: Double, end: Double) -> String {
        let trimmedSeconds = duration * (end - start)
        let mins = Int(trimmedSeconds) / 60
        let secs = Int(trimmedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Custom Video Player View (No Controls, Hardware Accelerated)

struct CustomVideoPlayerView: NSViewRepresentable {
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

// MARK: - Triangle Shape for Trim Markers

struct TriangleShape: Shape {
    enum Direction {
        case left, right
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .right:
            // Triangle pointing right (for start marker)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .left:
            // Triangle pointing left (for end marker)
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - View Extension for Conditional Modifiers
extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
