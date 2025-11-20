//
//  TipsManager.swift
//  VideoCullingApp
//
//  Manages loading and rotating display of tips and how-tos
//

import Foundation
import Combine

struct Tip: Codable, Identifiable {
    var id = UUID()
    let title: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case title
        case description
    }
}

class TipsManager: ObservableObject {
    static let shared = TipsManager()

    @Published var currentTip: Tip?
    @Published var tips: [Tip] = []

    private var rotationTimer: Timer?
    private var usedIndices: Set<Int> = []

    private init() {
        loadTips()
    }

    /// Load tips from the JSON file
    private func loadTips() {
        guard let url = Bundle.main.url(forResource: "tips", withExtension: "json") else {
            print("⚠️ Could not find tips.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            tips = try decoder.decode([Tip].self, from: data)
            print("✅ Loaded \(tips.count) tips")
        } catch {
            print("⚠️ Failed to load tips: \(error)")
        }
    }

    /// Start rotating through tips with a specified interval
    /// - Parameter interval: Time in seconds to show each tip (default: 7 seconds)
    func startRotation(interval: TimeInterval = 7.0) {
        guard !tips.isEmpty else { return }

        // Show first random tip immediately
        showNextTip()

        // Set up timer to rotate tips
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.showNextTip()
        }
    }

    /// Stop the tip rotation
    func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        currentTip = nil
        usedIndices.removeAll()
    }

    /// Show the next random tip (avoiding recent repeats)
    private func showNextTip() {
        guard !tips.isEmpty else { return }

        // Reset used indices if we've shown all tips
        if usedIndices.count >= tips.count {
            usedIndices.removeAll()
        }

        // Find available indices
        let availableIndices = Set(0..<tips.count).subtracting(usedIndices)

        // Select random tip from available
        if let randomIndex = availableIndices.randomElement() {
            usedIndices.insert(randomIndex)
            currentTip = tips[randomIndex]
        }
    }
}
