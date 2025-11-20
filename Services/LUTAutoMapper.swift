//
//  LUTAutoMapper.swift
//  VideoCullingApp
//

import Foundation

/// Automatically maps camera metadata to appropriate default LUTs
class LUTAutoMapper {

    /// Finds the best matching default LUT based on camera metadata
    static func findBestLUT(
        gamma: String?,
        colorSpace: String?,
        availableLUTs: [LUT]
    ) -> LUT? {
        print("🎨 LUTAutoMapper.findBestLUT called")
        print("   Gamma: \(gamma ?? "nil")")
        print("   ColorSpace: \(colorSpace ?? "nil")")
        print("   Total available LUTs: \(availableLUTs.count)")

        guard let gammaRaw = gamma?.lowercased(),
              let colorSpaceRaw = colorSpace?.lowercased() else {
            print("   ❌ Gamma or ColorSpace is nil, cannot auto-map")
            return nil
        }

        // Normalize strings by removing hyphens, dots, and spaces for matching
        let gamma = normalizeForMatching(gammaRaw)
        let colorSpace = normalizeForMatching(colorSpaceRaw)
        print("   Normalized Gamma: \(gamma)")
        print("   Normalized ColorSpace: \(colorSpace)")

        // FIRST: Check if user has taught the system a preference for this gamma/colorSpace
        if let userPreferredLUT = LUTManager.shared.getUserPreferredLUT(gamma: gamma, colorSpace: colorSpace) {
            print("   🎓 Using user's learned preference!")
            return userPreferredLUT
        }

        print("   💡 No user preference found, checking built-in mappings...")

        // Only consider default LUTs for auto-mapping
        let defaultLUTs = availableLUTs.filter { $0.name.hasPrefix("[Default]") }
        print("   Default LUTs available: \(defaultLUTs.count)")
        if defaultLUTs.isEmpty {
            print("   ⚠️ No default LUTs found! Available LUTs:")
            for lut in availableLUTs.prefix(5) {
                print("      - \(lut.name) (fileName: \(lut.fileName))")
            }
        }

        // Create mapping rules based on gamma and color space combinations
        let lutMappings: [(gammaPattern: String, colorPattern: String, lutPattern: String, priority: Int)] = [
            // Apple Log mappings
            ("applelog", "", "AppleLogToRec709", 10),
            ("applelog", "rec709", "AppleLogToRec709", 10),
            ("applelog", "rec.709", "AppleLogToRec709", 10),

            // S-Log3 + S-Gamut3.Cine mappings (most common modern Sony)
            ("slog3", "sgamut3-cine", "SGamut3CineSLog3_To_LC-709.cube", 10),  // s-gamut3-cine (with hyphen)
            ("slog3", "sgamut3.cine", "SGamut3CineSLog3_To_LC-709.cube", 10),  // sgamut3.cine (with dot)
            ("slog3", "sgamut3cine", "SGamut3CineSLog3_To_LC-709.cube", 10),   // sgamut3cine (no separator)
            ("slog3", "s-gamut3.cine", "SGamut3CineSLog3_To_LC-709.cube", 10), // s-gamut3.cine (full name with dot)

            // S-Log3 + S-Gamut3 mappings
            ("slog3", "sgamut3", "SGamut3CineSLog3_To_LC-709.cube", 9),
            ("slog3", "s-gamut3", "SGamut3CineSLog3_To_LC-709.cube", 9),

            // S-Log2 + S-Gamut mappings
            ("slog2", "sgamut", "SLog2SGumut_To_LC-709_", 10),
            ("slog2", "s-gamut", "SLog2SGumut_To_LC-709_", 10),

            // Generic S-Log3 (no color space specified)
            ("slog3", "", "SGamut3CineSLog3_To_LC-709.cube", 5),

            // Generic S-Log2 (no color space specified)
            ("slog2", "", "SLog2SGumut_To_LC-709_", 5),
        ]

        // Find all matching LUTs with their priority scores
        var matchedLUTs: [(lut: LUT, priority: Int)] = []

        for mapping in lutMappings {
            // Check if gamma matches
            let gammaMatches = mapping.gammaPattern.isEmpty || gamma.contains(mapping.gammaPattern)

            // Check if color space matches (or is not specified in the pattern)
            let colorMatches = mapping.colorPattern.isEmpty || colorSpace.contains(mapping.colorPattern)

            if gammaMatches && colorMatches {
                // Find LUTs that match this pattern
                for lut in defaultLUTs {
                    if lut.fileName.lowercased().contains(mapping.lutPattern.lowercased()) {
                        matchedLUTs.append((lut: lut, priority: mapping.priority))
                    }
                }
            }
        }

        // Sort by priority (highest first) and return the best match
        print("   Total matches found: \(matchedLUTs.count)")
        if let bestMatch = matchedLUTs.sorted(by: { $0.priority > $1.priority }).first {
            print("   ✅ Auto-mapped LUT: \(bestMatch.lut.name) (priority: \(bestMatch.priority))")
            print("      For Gamma: \(gamma), ColorSpace: \(colorSpace)")
            return bestMatch.lut
        }

        print("   ❌ No auto-mapping found for Gamma: \(gamma), ColorSpace: \(colorSpace)")
        return nil
    }

    /// Get a user-friendly description of the auto-mapping
    static func getMappingDescription(gamma: String?, colorSpace: String?) -> String {
        guard let gamma = gamma, let colorSpace = colorSpace else {
            return "No camera metadata available for auto-mapping"
        }

        // Normalize for matching
        let gammaNorm = normalizeForMatching(gamma.lowercased())
        let colorNorm = normalizeForMatching(colorSpace.lowercased())

        if gammaNorm.contains("slog3") && (colorNorm.contains("sgamut3cine") || colorNorm.contains("sgamut3")) {
            return "Auto-mapped: S-Log3/S-Gamut3.Cine → Rec.709"
        } else if gammaNorm.contains("slog3") && colorNorm.contains("sgamut3") {
            return "Auto-mapped: S-Log3/S-Gamut3 → Rec.709"
        } else if gammaNorm.contains("slog2") && colorNorm.contains("sgamut") {
            return "Auto-mapped: S-Log2/S-Gamut → Rec.709"
        } else if gammaNorm.contains("applelog") {
            return "Auto-mapped: Apple Log → Rec.709"
        } else if gammaNorm.contains("slog3") {
            return "Auto-mapped: S-Log3 → Rec.709 (assumed S-Gamut3.Cine)"
        } else if gammaNorm.contains("slog2") {
            return "Auto-mapped: S-Log2 → Rec.709 (assumed S-Gamut)"
        } else {
            return "No auto-mapping available for \(gamma)/\(colorSpace)"
        }
    }

    /// Normalize string for matching by removing hyphens, dots, and spaces
    static func normalizeForMatching(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
