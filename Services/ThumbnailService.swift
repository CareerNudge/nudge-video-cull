//
//  ThumbnailService.swift
//  VideoCullingApp
//
//  Manages throttled thumbnail generation to prevent resource exhaustion
//

import Foundation
import AVFoundation
import AppKit

@MainActor
class ThumbnailService: ObservableObject {
    static let shared = ThumbnailService()

    private let maxConcurrentGenerations = 3 // Limit simultaneous generations
    private var currentGenerations = 0
    private var pendingTasks: [(priority: Int, task: () async -> Void)] = []

    private init() {}

    /// Generate thumbnail with automatic throttling
    func generateThumbnail(
        for asset: AVAsset,
        at time: CMTime,
        maxSize: CGSize,
        priority: Int = 0
    ) async throws -> CGImage {
        // Wait if too many concurrent generations
        while currentGenerations >= maxConcurrentGenerations {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            if Task.isCancelled { throw CancellationError() }
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
