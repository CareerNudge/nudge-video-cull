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

// MARK: - User LUT Mapping (Learned Preferences)
struct UserLUTMapping: Codable {
    let gamma: String        // Lowercased gamma value (e.g., "s-log3-cine")
    let colorSpace: String   // Lowercased color space (e.g., "s-gamut3-cine")
    let lutId: String        // UUID string of the user's preferred LUT
    let lutName: String      // For display/debugging

    // Create a unique key for this gamma/colorSpace combination
    var key: String {
        "\(gamma)|\(colorSpace)"
    }
}

// MARK: - LUT Manager
class LUTManager: ObservableObject {
    static let shared = LUTManager()

    @Published var availableLUTs: [LUT] = []
    @Published var globalSelectedLUT: LUT?

    private let lutsDirectory: URL
    private let lutsListURL: URL
    private let userMappingsURL: URL
    private var userLUTMappings: [String: UserLUTMapping] = [:] // Key is "gamma|colorSpace"

    // Notification for when a new LUT preference is learned
    static let lutPreferenceLearnedNotification = Notification.Name("LUTPreferenceLearned")

    // Published event for learning (SwiftUI-friendly)
    @Published var lastLearnedMapping: UserLUTMapping?

    init() {
        // Create LUTs directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VideoCullingApp", isDirectory: true)
        self.lutsDirectory = appDirectory.appendingPathComponent("LUTs", isDirectory: true)
        self.lutsListURL = appDirectory.appendingPathComponent("luts.json")
        self.userMappingsURL = appDirectory.appendingPathComponent("userLUTMappings.json")

        // Create directories if needed
        try? FileManager.default.createDirectory(at: lutsDirectory, withIntermediateDirectories: true)

        // Load saved LUTs and user mappings
        loadLUTs()
        loadUserMappings()
    }

    // MARK: - Load/Save LUTs List

    private func loadLUTs() {
        // First, load default LUTs from app bundle
        var allLUTs: [LUT] = []
        allLUTs.append(contentsOf: loadDefaultLUTs())

        // Then, load user-imported LUTs from saved list
        if FileManager.default.fileExists(atPath: lutsListURL.path) {
            do {
                let data = try Data(contentsOf: lutsListURL)
                let userLUTs = try JSONDecoder().decode([LUT].self, from: data)
                allLUTs.append(contentsOf: userLUTs)
            } catch {
                print("Failed to load user LUTs: \(error)")
            }
        }

        availableLUTs = allLUTs
    }

    private func loadDefaultLUTs() -> [LUT] {
        var defaultLUTs: [LUT] = []

        // Get the DefaultLuts folder from the app bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            print("Could not find app bundle resource path")
            return defaultLUTs
        }

        let bundleURL = URL(fileURLWithPath: bundlePath)
        let defaultLutsPath = bundleURL.appendingPathComponent("DefaultLuts", isDirectory: true)

        // Try DefaultLuts folder first (if it exists as a folder reference)
        if FileManager.default.fileExists(atPath: defaultLutsPath.path) {
            print("Found DefaultLuts folder at: \(defaultLutsPath.path)")
            // Recursively find all .cube files in DefaultLuts
            if let enumerator = FileManager.default.enumerator(at: defaultLutsPath, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "cube" {
                        let fileName = fileURL.lastPathComponent
                        let lutName = fileURL.deletingPathExtension().lastPathComponent

                        // Store the full path relative to DefaultLuts for default LUTs
                        let relativePath = fileURL.path.replacingOccurrences(of: defaultLutsPath.path + "/", with: "")

                        let lut = LUT(name: "[Default] \(lutName)", fileName: "DefaultLuts/\(relativePath)")
                        defaultLUTs.append(lut)
                    }
                }
            }
        } else {
            // DefaultLuts folder not found - files may be copied flat to Resources
            // This happens when files are added as groups instead of folder references
            print("DefaultLuts folder not found, searching Resources root for .cube files")

            if let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "cube" {
                        let fileName = fileURL.lastPathComponent
                        let lutName = fileURL.deletingPathExtension().lastPathComponent

                        // These are default LUTs from the bundle, just stored flat
                        let lut = LUT(name: "[Default] \(lutName)", fileName: fileName)
                        defaultLUTs.append(lut)
                        print("Found default LUT: \(lutName)")
                    }
                }
            }
        }

        print("Loaded \(defaultLUTs.count) default LUTs from bundle")
        return defaultLUTs
    }

    private func saveLUTs() {
        // Only save user-imported LUTs (not default LUTs from bundle)
        let userLUTs = availableLUTs.filter { !isDefaultLUT($0) }

        do {
            let data = try JSONEncoder().encode(userLUTs)
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

    // MARK: - User LUT Mappings (Learning System)

    private func loadUserMappings() {
        guard FileManager.default.fileExists(atPath: userMappingsURL.path) else {
            print("No user LUT mappings file found (this is normal for first launch)")
            return
        }

        do {
            let data = try Data(contentsOf: userMappingsURL)
            let mappings = try JSONDecoder().decode([UserLUTMapping].self, from: data)

            // Convert array to dictionary for fast lookup
            userLUTMappings = Dictionary(uniqueKeysWithValues: mappings.map { ($0.key, $0) })

            print("✅ Loaded \(userLUTMappings.count) user LUT mappings")
        } catch {
            print("❌ Failed to load user LUT mappings: \(error)")
        }
    }

    private func saveUserMappings() {
        do {
            let mappings = Array(userLUTMappings.values)
            let data = try JSONEncoder().encode(mappings)
            try data.write(to: userMappingsURL)
            print("✅ Saved \(mappings.count) user LUT mappings")
        } catch {
            print("❌ Failed to save user LUT mappings: \(error)")
        }
    }

    /// Check if there's already a default mapping (built-in or user-defined) for this gamma/colorSpace
    func hasDefaultMapping(gamma: String?, colorSpace: String?) -> Bool {
        // Check if user has a learned preference
        if getUserPreferredLUT(gamma: gamma, colorSpace: colorSpace) != nil {
            return true
        }

        // Check if there's a built-in default mapping
        if LUTAutoMapper.findBestLUT(gamma: gamma, colorSpace: colorSpace, availableLUTs: availableLUTs) != nil {
            return true
        }

        return false
    }

    /// Learn from user's manual LUT selection
    /// Returns true if learning occurred, false if already has a default
    func learnLUTPreference(gamma: String?, colorSpace: String?, selectedLUT: LUT) -> Bool {
        guard let gammaRaw = gamma?.lowercased().trimmingCharacters(in: .whitespaces),
              let colorSpaceRaw = colorSpace?.lowercased().trimmingCharacters(in: .whitespaces),
              !gammaRaw.isEmpty, !colorSpaceRaw.isEmpty else {
            print("⚠️ Cannot learn LUT preference: gamma or colorSpace is empty")
            return false
        }

        // Normalize for consistent key matching
        let gamma = normalizeForMatching(gammaRaw)
        let colorSpace = normalizeForMatching(colorSpaceRaw)
        let key = "\(gamma)|\(colorSpace)"
        let mapping = UserLUTMapping(
            gamma: gamma,
            colorSpace: colorSpace,
            lutId: selectedLUT.id.uuidString,
            lutName: selectedLUT.name
        )

        userLUTMappings[key] = mapping
        saveUserMappings()

        print("🎓 Learned new LUT preference:")
        print("   Gamma: \(gamma)")
        print("   Color Space: \(colorSpace)")
        print("   Preferred LUT: \(selectedLUT.name)")

        // Publish notification for other views to update
        DispatchQueue.main.async {
            self.lastLearnedMapping = mapping
            NotificationCenter.default.post(
                name: Self.lutPreferenceLearnedNotification,
                object: nil,
                userInfo: [
                    "gamma": gamma,
                    "colorSpace": colorSpace,
                    "lutId": selectedLUT.id.uuidString,
                    "lutName": selectedLUT.name
                ]
            )
        }

        return true
    }

    /// Remove a learned LUT preference (undo)
    func forgetLUTPreference(gamma: String?, colorSpace: String?) {
        guard let gamma = gamma?.lowercased().trimmingCharacters(in: .whitespaces),
              let colorSpace = colorSpace?.lowercased().trimmingCharacters(in: .whitespaces),
              !gamma.isEmpty, !colorSpace.isEmpty else {
            return
        }

        let key = "\(gamma)|\(colorSpace)"
        userLUTMappings.removeValue(forKey: key)
        saveUserMappings()

        print("🗑️ Forgot LUT preference for \(gamma)/\(colorSpace)")
    }

    /// Get user's preferred LUT for given camera metadata (if they've taught the system)
    func getUserPreferredLUT(gamma: String?, colorSpace: String?) -> LUT? {
        guard let gammaRaw = gamma?.lowercased().trimmingCharacters(in: .whitespaces),
              let colorSpaceRaw = colorSpace?.lowercased().trimmingCharacters(in: .whitespaces),
              !gammaRaw.isEmpty, !colorSpaceRaw.isEmpty else {
            return nil
        }

        // Normalize for consistent key matching
        let gamma = normalizeForMatching(gammaRaw)
        let colorSpace = normalizeForMatching(colorSpaceRaw)
        let key = "\(gamma)|\(colorSpace)"
        guard let mapping = userLUTMappings[key] else {
            return nil
        }

        // Find the LUT by ID
        guard let lutId = UUID(uuidString: mapping.lutId),
              let lut = availableLUTs.first(where: { $0.id == lutId }) else {
            print("⚠️ User mapping exists but LUT not found: \(mapping.lutName)")
            return nil
        }

        print("🎓 Using learned LUT preference: \(lut.name) for \(gamma)/\(colorSpace)")
        return lut
    }

    // MARK: - Delete LUT

    func deleteLUT(_ lut: LUT) {
        // Don't allow deleting default LUTs from bundle
        guard !isDefaultLUT(lut) else {
            print("Cannot delete default LUT: \(lut.name)")
            return
        }

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

    // Helper to check if a LUT is a default (non-deletable) LUT
    func isDefaultLUT(_ lut: LUT) -> Bool {
        // Check both folder-based and flat-file default LUTs
        return lut.fileName.hasPrefix("DefaultLuts/") || lut.name.hasPrefix("[Default]")
    }

    // MARK: - Get LUT File URL

    func getLUTFileURL(for lut: LUT) -> URL {
        // Check if this is a default LUT from the bundle
        if lut.fileName.hasPrefix("DefaultLuts/") {
            // Return path from app bundle (folder structure preserved)
            guard let bundlePath = Bundle.main.resourcePath else {
                return lutsDirectory.appendingPathComponent(lut.fileName)
            }
            return URL(fileURLWithPath: bundlePath).appendingPathComponent(lut.fileName)
        } else if lut.name.hasPrefix("[Default]") {
            // This is a default LUT but stored flat in Resources (no DefaultLuts folder)
            guard let bundlePath = Bundle.main.resourcePath else {
                return lutsDirectory.appendingPathComponent(lut.fileName)
            }
            return URL(fileURLWithPath: bundlePath).appendingPathComponent(lut.fileName)
        } else {
            // Return path from user's LUTs directory
            return lutsDirectory.appendingPathComponent(lut.fileName)
        }
    }

    // MARK: - Apply LUT to Image

    func applyLUT(_ lut: LUT?, to image: CIImage) -> CIImage? {
        guard let lut = lut else { return image }

        let lutURL = getLUTFileURL(for: lut)
        print("🎨 Applying LUT: \(lut.name)")
        print("   LUT file path: \(lutURL.path)")

        guard FileManager.default.fileExists(atPath: lutURL.path) else {
            print("   ❌ LUT file not found at: \(lutURL.path)")
            return image
        }

        print("   ✅ LUT file exists")

        // Load and parse .cube file
        guard let lutData = try? String(contentsOf: lutURL, encoding: .utf8) else {
            print("   ❌ Failed to load LUT data")
            return image
        }

        // Parse the .cube file
        guard let cubeData = parseCubeLUT(lutData) else {
            print("   ❌ Failed to parse .cube file")
            return image
        }

        print("   ✅ Parsed .cube file, size: \(cubeData.dimension)")

        // Create color cube filter
        guard let filter = CIFilter(name: "CIColorCube") else {
            print("   ❌ Failed to create CIColorCube filter")
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(cubeData.dimension, forKey: "inputCubeDimension")
        filter.setValue(cubeData.data, forKey: "inputCubeData")

        print("   ✅ LUT filter created and configured")

        return filter.outputImage
    }

    // MARK: - Create LUT Filter (for video composition)

    func createLUTFilter(for lut: LUT) -> CIFilter? {
        let lutURL = getLUTFileURL(for: lut)
        print("🎨 Creating LUT filter: \(lut.name)")
        print("   LUT file path: \(lutURL.path)")

        guard FileManager.default.fileExists(atPath: lutURL.path) else {
            print("   ❌ LUT file not found at: \(lutURL.path)")
            return nil
        }

        // Load and parse .cube file
        guard let lutData = try? String(contentsOf: lutURL, encoding: .utf8) else {
            print("   ❌ Failed to load LUT data")
            return nil
        }

        // Parse the .cube file
        guard let cubeData = parseCubeLUT(lutData) else {
            print("   ❌ Failed to parse .cube file")
            return nil
        }

        print("   ✅ Parsed .cube file, size: \(cubeData.dimension)")

        // Create color cube filter (without setting input image)
        guard let filter = CIFilter(name: "CIColorCube") else {
            print("   ❌ Failed to create CIColorCube filter")
            return nil
        }

        filter.setValue(cubeData.dimension, forKey: "inputCubeDimension")
        filter.setValue(cubeData.data, forKey: "inputCubeData")

        print("   ✅ LUT filter created and configured")

        return filter
    }

    // Parse a .cube LUT file and return the color cube data
    private func parseCubeLUT(_ content: String) -> (data: Data, dimension: Int)? {
        var dimension = 0
        var rgbValues: [[Float]] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse LUT_3D_SIZE
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 2, let size = Int(components[1]) {
                    dimension = size
                }
                continue
            }

            // Parse RGB values
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count == 3,
               let r = Float(components[0]),
               let g = Float(components[1]),
               let b = Float(components[2]) {
                rgbValues.append([r, g, b, 1.0]) // RGBA, alpha always 1
            }
        }

        guard dimension > 0 else {
            print("   ❌ No LUT_3D_SIZE found in .cube file")
            return nil
        }

        let expectedCount = dimension * dimension * dimension
        guard rgbValues.count == expectedCount else {
            print("   ❌ Expected \(expectedCount) RGB values but got \(rgbValues.count)")
            return nil
        }

        // Convert to Data format expected by CIColorCube
        var floatArray: [Float] = []
        for rgb in rgbValues {
            floatArray.append(contentsOf: rgb)
        }

        let data = Data(bytes: floatArray, count: floatArray.count * MemoryLayout<Float>.size)
        return (data: data, dimension: dimension)
    }

    // MARK: - Helper Functions

    /// Normalize string for matching by removing hyphens, dots, and spaces
    private func normalizeForMatching(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
