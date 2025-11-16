//
//  PlayerView.swift
//  VideoCullingApp
//

import SwiftUI
import AVKit
import AVFoundation

struct PlayerView: View {
    @ObservedObject var asset: ManagedVideoAsset
    @Binding var localTrimStart: Double
    @Binding var localTrimEnd: Double

    @State private var player: AVPlayer?
    @State private var thumbnail: NSImage?
    @State private var isPlaying = false
    @State private var showFullscreen = false
    @State private var previewImage: NSImage?
    @State private var imageGenerator: AVAssetImageGenerator?

    var body: some View {
        VStack(spacing: 8) {
            // Video Preview Area
            GeometryReader { geometry in
                ZStack {
                    if isPlaying, let player = player {
                        // Show inline video player
                        VideoPlayer(player: player)
                            .frame(height: 220)
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                                player.seek(to: .zero)
                            }

                        // Stop button overlay when playing
                        VStack {
                            HStack {
                                Button(action: {
                                    player.pause()
                                    player.seek(to: .zero)
                                    isPlaying = false
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: "stop.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16)
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(8)

                                Spacer()
                            }
                            Spacer()
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

                        // Play button overlay (only show when not scrubbing)
                        if previewImage == nil {
                            Button(action: {
                                isPlaying = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Fullscreen button in bottom-right corner (always visible)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                if isPlaying, let player = player {
                                    player.pause()
                                    isPlaying = false
                                }
                                showFullscreen = true
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 30, height: 30)

                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
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
                }
            }
            .frame(height: 220)
            .cornerRadius(8)

            // Trim Range Slider
            TrimRangeSlider(
                start: $localTrimStart,
                end: $localTrimEnd,
                duration: asset.duration,
                onScrub: { normalizedTime in
                    generatePreviewFrame(at: normalizedTime)
                },
                onScrubEnd: {
                    previewImage = nil
                }
            )

            // Audio Waveform
            WaveformView(
                asset: asset,
                trimStart: $localTrimStart,
                trimEnd: $localTrimEnd
            )
        }
        .onAppear {
            loadThumbnailAndPlayer()
        }
        .sheet(isPresented: $showFullscreen) {
            if let player = player {
                FullscreenPlayerView(
                    player: player,
                    trimStart: $localTrimStart,
                    trimEnd: $localTrimEnd,
                    duration: asset.duration,
                    isPresented: $showFullscreen
                )
            }
        }
    }

    private func loadThumbnailAndPlayer() {
        guard let url = asset.fileURL else {
            print("Invalid file path for asset: \(asset.fileName ?? "unknown")")
            return
        }

        // Create player - always create it, security scope is handled by the file system
        _ = url.startAccessingSecurityScopedResource()
        self.player = AVPlayer(url: url)

        // Generate thumbnail and set up image generator
        Task {
            let avAsset = AVAsset(url: url)
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
                await MainActor.run {
                    self.thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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

                await MainActor.run {
                    self.previewImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    print("✅ Set previewImage on MainActor")
                }
            } catch {
                print("❌ Failed to generate preview frame: \(error)")
            }
        }
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
            // Video player
            VideoPlayer(player: player)
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
            .frame(height: 120)
            .background(Color(NSColor.windowBackgroundColor))
        }
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
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: max(0, endX - startX), height: 6)
                        .position(x: startX + (endX - startX) / 2, y: 10)
                        .cornerRadius(3)

                    // Start handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
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

                    // End handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
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
}
