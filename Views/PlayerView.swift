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
    var onVideoEnded: (() -> Void)?  // Callback for play-through
    var shouldAutoPlay: Bool = false  // Trigger for auto-play
    var isSelected: Bool = false  // Indicates if this row is the active/selected row for hotkeys

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
    @State private var hasAutoPlayed = false  // Track if auto-play has been triggered
    @State private var videoEndObserver: NSObjectProtocol?  // Token for NotificationCenter observer
    private let hotkeyManager = HotkeyManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Import/Deletion status toggle (above video)
            HStack(spacing: 0) {
                // Left side: Checkmark (Import/Preserve)
                Button(action: {
                    if asset.isFlaggedForDeletion {
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
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(asset.isFlaggedForDeletion ? Color.gray.opacity(0.1) : Color.blue.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                // Right side: X (Delete/Don't Import)
                Button(action: {
                    if !asset.isFlaggedForDeletion {
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
                    .foregroundColor(asset.isFlaggedForDeletion ? .red : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(asset.isFlaggedForDeletion ? Color.red.opacity(0.15) : Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

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
                                removeVideoEndObserver()

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
                        startPlayback()
                    }
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(asset.isFlaggedForDeletion)

                // Current Time
                Text(formatTime(currentPosition * asset.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Position Slider (constrained to trim range)
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

                        // Trimmed Duration Display (centered between trim points)
                        if localTrimStart > 0.001 || localTrimEnd < 0.999 {
                            let trimmedDuration = (localTrimEnd - localTrimStart) * asset.duration
                            let centerX = (trimStartX + trimEndX) / 2

                            Text(formatTime(trimmedDuration))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.9))
                                )
                                .position(x: centerX, y: -8)
                        }

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

                // Duration
                Text(formatTime(asset.duration * localTrimEnd))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 4)

            // Trim controls are now integrated into the playback slider above
            // (Triangular handles on the same line as playback slider)

            // Audio Waveform
            WaveformView(
                asset: asset,
                trimStart: $localTrimStart,
                trimEnd: $localTrimEnd
            )
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
        .onChange(of: shouldAutoPlay) { newValue in
            // Auto-play when triggered by play-through
            if newValue && !hasAutoPlayed && preferences.videoPlayThroughEnabled {
                print("🎬 Auto-playing video: \(asset.fileName ?? "unknown")")
                hasAutoPlayed = true
                isPlaying = true
            }
        }
        .onChange(of: localTrimStart) { newStart in
            // Seek to new trim start when slider is moved
            seekToTrimPosition(newStart)
        }
        .onChange(of: localTrimEnd) { newEnd in
            // If currently playing and we moved end point before current position, seek to end
            if isPlaying, let player = player {
                let currentTime = CMTimeGetSeconds(player.currentTime())
                let endTime = asset.duration * newEnd
                if currentTime > endTime {
                    seekToTrimPosition(newEnd)
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
        .onDisappear {
            // Clean up hotkeys if selected
            if isSelected {
                clearHotkeyCallbacks()
            }
            // Clean up notification observer
            removeVideoEndObserver()
            // Clean up time observer
            removeTimeObserver()
            // Reset auto-play flag when view disappears
            hasAutoPlayed = false
        }
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

    // MARK: - Trim-Aware Playback

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
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
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
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
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

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Thumbnail and Player Setup

    private func loadThumbnailAndPlayer() {
        guard let url = asset.fileURL else {
            print("Invalid file path for asset: \(asset.fileName ?? "unknown")")
            return
        }

        // Remove existing time observer before creating new player
        removeTimeObserver()

        // Create player - always create it, security scope is handled by the file system
        _ = url.startAccessingSecurityScopedResource()

        // Create AVAsset for composition
        let avAsset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: avAsset)
        let newPlayer = AVPlayer(playerItem: playerItem)

        // Enable automatic waiting to minimize stalls for smoother playback
        newPlayer.automaticallyWaitsToMinimizeStalling = true

        // Use automatic resource allocation for better performance
        if #available(macOS 12.0, *) {
            newPlayer.audiovisualBackgroundPlaybackPolicy = .automatic
        }

        self.player = newPlayer

        // Set up video end notification for play-through
        setupVideoEndNotification(for: newPlayer)

        // Apply video composition with LUT if selected
        Task {
            if let composition = await createLUTVideoComposition(for: avAsset, lutId: asset.selectedLUTId) {
                await MainActor.run {
                    playerItem.videoComposition = composition
                    print("✅ Video composition with LUT applied to player")
                }
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
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)

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
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
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

        // Create a CIContext with the same settings as used for still images
        let renderContext = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false, // Force GPU rendering
            .priorityRequestLow: false // High priority
        ])

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
                request.finish(with: croppedImage, context: renderContext)
            } else {
                // Fallback to source if LUT fails
                request.finish(with: sourceImage, context: renderContext)
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

    private func applyLUTToImage(cgImage: CGImage) async -> NSImage {
        print("🎨 applyLUTToImage called for asset: \(asset.fileName ?? "unknown")")
        print("   selectedLUTId: \(asset.selectedLUTId ?? "nil")")

        guard let lutIdString = asset.selectedLUTId,
              !lutIdString.isEmpty,
              let lutId = UUID(uuidString: lutIdString),
              let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == lutId }) else {
            print("   ❌ No LUT selected or LUT not found, returning original image")
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        print("   ✅ Found LUT: \(selectedLUT.name)")

        let ciImage = CIImage(cgImage: cgImage)
        print("   📷 Converting CGImage to CIImage, size: \(ciImage.extent)")

        if let lutAppliedImage = lutManager.applyLUT(selectedLUT, to: ciImage) {
            print("   ✅ LUT applied successfully")
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

        print("   ⚠️ Returning original image (LUT application failed)")
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Play-Through Support

    private func setupVideoEndNotification(for player: AVPlayer) {
        // Remove any existing observer first
        removeVideoEndObserver()

        guard preferences.videoPlayThroughEnabled else {
            print("🎬 Play-through is disabled")
            return
        }

        // Store the observer token so we can remove it later
        videoEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            self.handleVideoEnded()
        }

        print("🎬 Set up video end notification for play-through")
    }

    private func removeVideoEndObserver() {
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
            print("🎬 Removed video end observer")
        }
    }

    private func handleVideoEnded() {
        guard preferences.videoPlayThroughEnabled else { return }

        print("🎬 Video ended, starting 2-second delay for play-through")

        // Stop the player
        player?.pause()
        isPlaying = false

        // Wait 2 seconds, then notify parent to advance
        let callback = onVideoEnded
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🎬 2-second delay complete, advancing to next video")
            callback?()
        }
    }

    // MARK: - Hotkey Callbacks

    private func setupHotkeyCallbacks() {
        // Capture necessary values to avoid capturing self
        let asset = self.asset
        let player = self.player
        let currentPosition = self.currentPosition
        let formatTime = self.formatTime

        // Play/Pause toggle
        hotkeyManager.onTogglePlayPause = {
            Task { @MainActor in
                // Note: Since PlayerView is a struct, we can't directly modify state from closure
                // The play/pause will need to be handled differently
                player?.play()
            }
        }

        // Set in point (trim start)
        hotkeyManager.onSetInPoint = {
            Task { @MainActor in
                asset.trimStartTime = currentPosition
                try? asset.managedObjectContext?.save()
                print("✂️ In point set at \(formatTime(currentPosition * asset.duration))")
            }
        }

        // Set out point (trim end)
        hotkeyManager.onSetOutPoint = {
            Task { @MainActor in
                asset.trimEndTime = currentPosition
                try? asset.managedObjectContext?.save()
                player?.pause()
                print("✂️ Out point set at \(formatTime(currentPosition * asset.duration))")
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
}

// MARK: - Fullscreen Player View
struct FullscreenPlayerView: View {
    let player: AVPlayer
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    let duration: Double
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Video player - takes up all available space
            VideoPlayer(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                    player.seek(to: .zero)
                }

            // Trim controls at bottom
            VStack(spacing: 12) {
                Text("Trim Range")
                    .font(.headline)

                TrimRangeSlider(
                    start: $trimStart,
                    end: $trimEnd,
                    duration: duration
                )
                .padding(.horizontal, 40)

                HStack(spacing: 20) {
                    Button("Close") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.bottom, 20)
            }
            .frame(height: 140)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Triangle Shape for Trim Handles
struct Triangle: Shape {
    var pointingRight: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if pointingRight {
            // Right-pointing triangle (for start handle)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            // Left-pointing triangle (for end handle)
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Trim Range Slider
struct TrimRangeSlider: View {
    @Binding var start: Double
    @Binding var end: Double
    let duration: Double
    var onScrub: ((Double) -> Void)? = nil
    var onScrubEnd: (() -> Void)? = nil
    var showLabels: Bool = true

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
                    // Background track (dimmed areas outside trim range)
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

                    // Start handle - right-pointing triangle
                    Triangle(pointingRight: true)
                        .fill(Color.white)
                        .frame(width: 16, height: 20)
                        .overlay(Triangle(pointingRight: true).stroke(Color.blue, lineWidth: 2))
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

                    // End handle - left-pointing triangle
                    Triangle(pointingRight: false)
                        .fill(Color.white)
                        .frame(width: 16, height: 20)
                        .overlay(Triangle(pointingRight: false).stroke(Color.blue, lineWidth: 2))
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

            // Time labels (optional)
            if showLabels {
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

// MARK: - Custom Video Compositor for LUT Application

class LUTVideoCompositor: NSObject, AVVideoCompositing {
    static var currentLUTFilter: CIFilter?

    private let renderContext = CIContext()
    private let renderQueue = DispatchQueue(label: "com.videocull.lutcompositor")

    var sourcePixelBufferAttributes: [String : Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferOpenGLCompatibilityKey as String: true
    ]

    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferOpenGLCompatibilityKey as String: true
    ]

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Context changed, nothing to do
    }

    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async {
            guard let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[0].int32Value) else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "LUTVideoCompositor", code: -1))
                return
            }

            // Check if we have a LUT filter to apply
            if let lutFilter = LUTVideoCompositor.currentLUTFilter {
                // Create CIImage from source pixel buffer
                let sourceImage = CIImage(cvPixelBuffer: sourcePixelBuffer)

                // Apply LUT filter
                lutFilter.setValue(sourceImage, forKey: kCIInputImageKey)

                if let outputImage = lutFilter.outputImage {
                    // Render directly to the source pixel buffer (in-place)
                    self.renderContext.render(outputImage, to: sourcePixelBuffer)
                    asyncVideoCompositionRequest.finish(withComposedVideoFrame: sourcePixelBuffer)
                    return
                }
            }

            // If no LUT or rendering failed, return original frame
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: sourcePixelBuffer)
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        // Cancel any pending requests
        renderQueue.sync {
            // Nothing to cancel in this simple implementation
        }
    }
}

// MARK: - Custom Video Player View (No Controls)

struct CustomVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

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
