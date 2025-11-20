//
//  PlayerPool.swift
//  VideoCullingApp
//
//  Created to optimize video playback performance by reusing AVPlayer instances
//  instead of creating new ones for each video.
//

import Foundation
import AVFoundation

/// Singleton service that manages a pool of reusable AVPlayer instances
/// to improve video switching performance and reduce memory usage.
@MainActor
class PlayerPool {
    static let shared = PlayerPool()

    private var availablePlayers: [AVPlayer] = []
    private var activePlayers: Set<ObjectIdentifier> = []
    private let maxPoolSize = 3  // Limit pool to 3 players

    private init() {
        print("🏊 PlayerPool initialized (max size: \(maxPoolSize))")
    }

    /// Acquire a player from the pool or create a new one if pool is empty
    /// - Returns: An AVPlayer instance ready for use
    func acquirePlayer() -> AVPlayer {
        // Try to reuse a player from the pool
        if let player = availablePlayers.popLast() {
            let playerId = ObjectIdentifier(player)
            activePlayers.insert(playerId)
            print("♻️ Reusing pooled AVPlayer (\(availablePlayers.count) remaining in pool)")
            return player
        }

        // Pool is empty, create a new player
        let newPlayer = AVPlayer()
        let playerId = ObjectIdentifier(newPlayer)
        activePlayers.insert(playerId)
        print("🆕 Creating new AVPlayer (pool exhausted, \(activePlayers.count) active)")
        return newPlayer
    }

    /// Return a player to the pool for reuse
    /// - Parameter player: The AVPlayer instance to return
    func releasePlayer(_ player: AVPlayer) {
        let playerId = ObjectIdentifier(player)

        // Only release players that we're tracking
        guard activePlayers.contains(playerId) else {
            print("⚠️ Attempted to release untracked player")
            return
        }

        // Clean up player state before returning to pool
        player.pause()
        player.seek(to: .zero)
        player.replaceCurrentItem(with: nil)

        // Return to pool if not full, otherwise discard
        if availablePlayers.count < maxPoolSize {
            availablePlayers.append(player)
            activePlayers.remove(playerId)
            print("✅ Player returned to pool (\(availablePlayers.count)/\(maxPoolSize) pooled, \(activePlayers.count) active)")
        } else {
            activePlayers.remove(playerId)
            print("🗑️ Player discarded (pool full at \(maxPoolSize), \(activePlayers.count) active)")
        }
    }

    /// Drain the pool, releasing all cached players
    /// Call this when the app goes to background or when memory pressure is high
    func drainPool() {
        let drained = availablePlayers.count
        availablePlayers.removeAll()
        print("💧 Player pool drained (\(drained) players released, \(activePlayers.count) still active)")
    }

    /// Get current pool statistics for debugging
    func getStats() -> (pooled: Int, active: Int, maxSize: Int) {
        return (availablePlayers.count, activePlayers.count, maxPoolSize)
    }
}
