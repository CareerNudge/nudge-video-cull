//
//  FCPXMLExporter.swift
//  VideoCullingApp
//
//  FCPXML export service for Final Cut Pro integration
//

import Foundation
import AppKit
import AVFoundation

class FCPXMLExporter {

    // MARK: - Public Export Function

    func export(assets: [ManagedVideoAsset]) throws {
        guard !assets.isEmpty else {
            throw ExportError.noAssets
        }

        // Generate the FCPXML content
        let fcpxmlContent = generateFCPXML(assets: assets)

        // Present save panel to user
        let savePanel = NSSavePanel()
        savePanel.title = "Export FCPXML"
        savePanel.message = "Choose where to save the FCPXML file"
        savePanel.nameFieldStringValue = "NudgeVideoCull_\(Date().formatForFilename()).fcpxml"
        savePanel.allowedContentTypes = [.xml]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try fcpxmlContent.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ FCPXML exported successfully to: \(url.path)")
                } catch {
                    print("❌ Failed to write FCPXML: \(error)")
                }
            }
        }
    }

    // MARK: - FCPXML Generation

    private func generateFCPXML(assets: [ManagedVideoAsset]) -> String {
        // Determine format from first asset (or use defaults)
        let formatWidth = assets.first?.videoWidth ?? 1920
        let formatHeight = assets.first?.videoHeight ?? 1080
        let formatFrameRate = assets.first?.frameRate ?? 30.0
        let frameDuration = formatFrameRate > 0 ? "1/\(Int(formatFrameRate))s" : "1001/30000s"

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>

        <fcpxml version="1.9">
            <resources>
                <format id="r1" name="FFVideoFormat\(formatWidth)x\(formatHeight)p\(Int(formatFrameRate))" frameDuration="\(frameDuration)" width="\(formatWidth)" height="\(formatHeight)" colorSpace="1-1-1 (Rec. 709)"/>

        """

        // Add all assets as resources
        for (index, asset) in assets.enumerated() {
            xml += generateAssetResource(asset: asset, index: index)
        }

        xml += """
            </resources>
            <library>
                <event name="Nudge Video Cull Import">
                    <project name="Imported Clips">
                        <sequence format="r1" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
                            <spine>

        """

        // Add all clips to the timeline
        for (index, asset) in assets.enumerated() {
            xml += generateClipReference(asset: asset, index: index)
        }

        xml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """

        return xml
    }

    private func generateAssetResource(asset: ManagedVideoAsset, index: Int) -> String {
        guard let filePath = asset.filePath else { return "" }

        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let resourceID = "r\(index + 2)" // Start from r2 (r1 is format)

        // Get video duration in seconds
        let duration = asset.duration
        let frameDuration = "1/\(Int(asset.frameRate))s"

        return """
                <asset id="\(resourceID)" name="\(fileName.xmlEscaped)" start="0s" duration="\(duration)s" hasVideo="1" hasAudio="1">
                    <media-rep kind="original-media" src="file://\(filePath.xmlEscaped)"/>
                    <metadata>
                        <md key="com.apple.proapps.spotlight.kMDItemKeywords" value="\(asset.keywords?.xmlEscaped ?? "")"/>
                        <md key="com.apple.proapps.studio.ratingAnnotation" value="\(asset.userRating)"/>
                    </metadata>
                </asset>

        """
    }

    private func generateClipReference(asset: ManagedVideoAsset, index: Int) -> String {
        let resourceID = "r\(index + 2)"
        let clipName = asset.fileName?.xmlEscaped ?? "Clip \(index + 1)"

        // Calculate trim points
        let totalDuration = asset.duration
        let trimStart = asset.trimStartTime
        let trimEnd = asset.trimEndTime > 0 && asset.trimEndTime < 0.999 ? asset.trimEndTime : 1.0

        let startTime = trimStart * totalDuration
        let endTime = trimEnd * totalDuration
        let trimmedDuration = endTime - startTime

        // Build metadata section
        var metadataXML = ""
        if let keywords = asset.keywords, !keywords.isEmpty {
            metadataXML += """
                            <metadata>
                                <md key="com.apple.proapps.spotlight.kMDItemKeywords" value="\(keywords.xmlEscaped)"/>
                                <md key="com.apple.proapps.studio.ratingAnnotation" value="\(asset.userRating)"/>
                            </metadata>

            """
        }

        return """
                                <asset-clip name="\(clipName)" offset="0s" ref="\(resourceID)" duration="\(trimmedDuration)s" start="\(startTime)s" tcFormat="NDF">
        \(metadataXML)                        </asset-clip>

        """
    }

    // MARK: - Error Types

    enum ExportError: Error, LocalizedError {
        case noAssets
        case invalidAsset

        var errorDescription: String? {
            switch self {
            case .noAssets:
                return "No assets available to export"
            case .invalidAsset:
                return "One or more assets are invalid"
            }
        }
    }
}

// MARK: - Helper Extensions

extension String {
    var xmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

extension Date {
    func formatForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: self)
    }
}
