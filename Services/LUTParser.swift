//
//  LUTParser.swift
//  VideoCullingApp
//
//  Parses .cube LUT files for use with CoreImage filters
//

import Foundation
import CoreImage

struct LUTData {
    let dimension: Int
    let data: Data
}

class LUTParser {

    static func parse(lutURL: URL) throws -> LUTData {
        let contents = try String(contentsOf: lutURL, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines)

        var dimension = 33 // Default cube dimension
        var lutValues: [Float] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // Parse dimension line
            if trimmedLine.hasPrefix("LUT_3D_SIZE") {
                let components = trimmedLine.components(separatedBy: .whitespaces)
                if components.count >= 2, let size = Int(components[1]) {
                    dimension = size
                }
                continue
            }

            // Parse RGB data
            let components = trimmedLine.components(separatedBy: .whitespaces)
            if components.count >= 3 {
                if let r = Float(components[0]),
                   let g = Float(components[1]),
                   let b = Float(components[2]) {
                    lutValues.append(r)
                    lutValues.append(g)
                    lutValues.append(b)
                    lutValues.append(1.0) // Alpha channel
                }
            }
        }

        // Verify we have the correct amount of data
        let expectedCount = dimension * dimension * dimension * 4 // RGBA
        guard lutValues.count == expectedCount else {
            throw NSError(
                domain: "LUTParser",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid LUT data: expected \(expectedCount) values, got \(lutValues.count)"]
            )
        }

        // Convert to Data
        let data = Data(bytes: lutValues, count: lutValues.count * MemoryLayout<Float>.size)

        return LUTData(dimension: dimension, data: data)
    }

    static func createColorCubeFilter(from lutData: LUTData) -> CIFilter? {
        guard let filter = CIFilter(name: "CIColorCube") else {
            return nil
        }

        filter.setValue(lutData.dimension, forKey: "inputCubeDimension")
        filter.setValue(lutData.data, forKey: "inputCubeData")

        return filter
    }
}
