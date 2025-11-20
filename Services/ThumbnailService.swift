//
//  ThumbnailService.swift
//  VideoCullingApp
//
//  Manages throttled thumbnail generation to prevent resource exhaustion
//

import Foundation
import AVFoundation
import AppKit

class ThumbnailService: ObservableObject {
    static let shared = ThumbnailService()

    private let maxConcurrentGenerations = 3 // Limit simultaneous generations
    private var currentGenerations = 0
    private var pendingTasks: [(priority: Int, task: () async -> Void)] = []

    /// Track pending filmstrip thumbnail generations for "Ready" status
    @MainActor @Published var pendingFilmstripThumbnails = 0

    private init() {}

    /// Generate thumbnail with automatic throttling
    /// - Parameters:
    ///   - asset: The video asset
    ///   - time: Time position for thumbnail
    ///   - maxSize: Maximum thumbnail dimensions
    ///   - priority: Priority level (unused currently)
    ///   - immediate: If true, bypass throttling for instant generation (used for selected video preview)
    ///   - isFilmstrip: If true, count towards filmstrip completion tracking
    func generateThumbnail(
        for asset: AVAsset,
        at time: CMTime,
        maxSize: CGSize,
        priority: Int = 0,
        immediate: Bool = false,
        isFilmstrip: Bool = false
    ) async throws -> CGImage {
        // Track filmstrip thumbnail generation
        if isFilmstrip {
            await MainActor.run {
                pendingFilmstripThumbnails += 1
            }
        }

        defer {
            if isFilmstrip {
                Task { @MainActor in
                    pendingFilmstripThumbnails -= 1
                }
            }
        }

        // Wait if too many concurrent generations (unless immediate mode)
        if !immediate {
            while currentGenerations >= maxConcurrentGenerations {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                if Task.isCancelled { throw CancellationError() }
            }
        }

        currentGenerations += 1
        defer { currentGenerations -= 1 }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // Use async API to avoid blocking
        let result = try await generator.image(at: time)
        return result.image
    }
}
