//
//  LUTManager.swift
//  VideoCullingApp
//

import Foundation
import SwiftUI
import CoreImage

// MARK: - LUT Model
struct LUT: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fileName: String

    init(id: UUID = UUID(), name: String, fileName: String) {
        self.id = id
        self.name = name
        self.fileName = fileName
    }
}

// MARK: - LUT Manager
class LUTManager: ObservableObject {
    static let shared = LUTManager()

    @Published var availableLUTs: [LUT] = []
    @Published var globalSelectedLUT: LUT?

    private let lutsDirectory: URL
    private let lutsListURL: URL

    init() {
        // Create LUTs directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VideoCullingApp", isDirectory: true)
        self.lutsDirectory = appDirectory.appendingPathComponent("LUTs", isDirectory: true)
        self.lutsListURL = appDirectory.appendingPathComponent("luts.json")

        // Create directories if needed
        try? FileManager.default.createDirectory(at: lutsDirectory, withIntermediateDirectories: true)

        // Load saved LUTs
        loadLUTs()
    }

    // MARK: - Load/Save LUTs List

    private func loadLUTs() {
        guard FileManager.default.fileExists(atPath: lutsListURL.path) else {
            availableLUTs = []
            return
        }

        do {
            let data = try Data(contentsOf: lutsListURL)
            let luts = try JSONDecoder().decode([LUT].self, from: data)
            availableLUTs = luts
        } catch {
            print("Failed to load LUTs: \(error)")
            availableLUTs = []
        }
    }

    private func saveLUTs() {
        do {
            let data = try JSONEncoder().encode(availableLUTs)
            try data.write(to: lutsListURL)
        } catch {
            print("Failed to save LUTs: \(error)")
        }
    }

    // MARK: - Import LUT

    func importLUT(from sourceURL: URL) -> Bool {
        let fileName = sourceURL.lastPathComponent
        let lutName = sourceURL.deletingPathExtension().lastPathComponent
        let destinationURL = lutsDirectory.appendingPathComponent(fileName)

        print("Importing LUT: \(lutName)")
        print("Source: \(sourceURL.path)")
        print("Destination: \(destinationURL.path)")

        do {
            // Create LUTs directory if it doesn't exist
            try FileManager.default.createDirectory(at: lutsDirectory, withIntermediateDirectories: true)

            // Copy LUT file to app's LUTs directory
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("Removing existing LUT file")
                try FileManager.default.removeItem(at: destinationURL)
            }

            print("Copying LUT file...")
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            // Add to list
            let newLUT = LUT(name: lutName, fileName: fileName)
            availableLUTs.append(newLUT)
            saveLUTs()

            print("LUT imported successfully. Total LUTs: \(availableLUTs.count)")
            return true
        } catch {
            print("Failed to import LUT: \(error)")
            print("Error details: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Delete LUT

    func deleteLUT(_ lut: LUT) {
        let lutFileURL = lutsDirectory.appendingPathComponent(lut.fileName)

        // Delete file
        try? FileManager.default.removeItem(at: lutFileURL)

        // Remove from list
        availableLUTs.removeAll { $0.id == lut.id }
        saveLUTs()

        // Clear global selection if this was it
        if globalSelectedLUT?.id == lut.id {
            globalSelectedLUT = nil
        }
    }

    // MARK: - Get LUT File URL

    func getLUTFileURL(for lut: LUT) -> URL {
        return lutsDirectory.appendingPathComponent(lut.fileName)
    }

    // MARK: - Apply LUT to Image

    func applyLUT(_ lut: LUT?, to image: CIImage) -> CIImage? {
        guard let lut = lut else { return image }

        let lutURL = getLUTFileURL(for: lut)
        guard FileManager.default.fileExists(atPath: lutURL.path) else {
            print("LUT file not found: \(lutURL.path)")
            return image
        }

        // Load LUT data
        guard let lutData = try? Data(contentsOf: lutURL) else {
            print("Failed to load LUT data")
            return image
        }

        // Create color cube filter
        // This is a simplified implementation - real .cube files need proper parsing
        if let filter = CIFilter(name: "CIColorCube") {
            // For .cube files, you'd parse them and create the cube data
            // For now, this is a placeholder for the filter setup
            filter.setValue(image, forKey: kCIInputImageKey)

            // TODO: Parse .cube file and set up the color cube data properly
            // This would involve reading the LUT file and converting it to the format
            // expected by CIColorCube filter

            return filter.outputImage
        }

        return image
    }
}
