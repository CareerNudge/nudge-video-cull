//
//  MetadataView.swift
//  VideoCullingApp
//

import SwiftUI

struct MetadataView: View {
    @ObservedObject var asset: ManagedVideoAsset
    
    // Values passed from the parent
    let isTrimmed: Bool
    let estimatedDuration: Double
    let estimatedSize: Int64
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(asset.fileName ?? "Unknown File")
                .font(.headline)
                .lineLimit(1)

            Text(asset.filePath ?? "Unknown Path")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Divider().padding(.vertical, 4)

            // --- Dynamic Metadata ---

            // Duration - show original + estimated
            if isTrimmed {
                MetadataRowWithEstimate(
                    label: "Duration",
                    originalValue: formattedDuration(asset.duration),
                    estimatedValue: formattedDuration(estimatedDuration)
                )
            } else {
                MetadataRow(label: "Duration", value: formattedDuration(asset.duration))
            }

            // Size - show original + estimated
            if isTrimmed {
                MetadataRowWithEstimate(
                    label: "Size",
                    originalValue: formattedSize(asset.fileSize),
                    estimatedValue: formattedSize(estimatedSize)
                )
            } else {
                MetadataRow(label: "Size", value: formattedSize(asset.fileSize))
            }

            MetadataRow(label: "Bitrate", value: formattedBitrate(asset.bitrate))
                .font(.subheadline)

            // Framerate with slow motion indicator
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Framerate:")
                    .frame(width: 80, alignment: .leading)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text(String(format: "%.2f FPS", asset.frameRate))

                // Show slow motion indicator if capture FPS differs from playback framerate
                if let captureFpsString = asset.captureFps {
                    // Clean the string by removing 'p' suffix and any whitespace
                    let cleanedString = captureFpsString.replacingOccurrences(of: "p", with: "").trimmingCharacters(in: .whitespaces)
                    if let captureFps = Double(cleanedString),
                       captureFps > 0 && abs(captureFps - asset.frameRate) > 0.1 {
                        let slowMotionFactor = captureFps / asset.frameRate
                        Text(String(format: "(%.0fx Slow Motion)", slowMotionFactor))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .font(.subheadline)

            Divider().padding(.vertical, 2)

            // Video resolution/dimensions
            MetadataRow(label: "Resolution", value: formattedResolution(width: asset.videoWidth, height: asset.videoHeight))
                .font(.subheadline)

            // Video codec information
            MetadataRow(label: "Video Codec", value: asset.videoCodec ?? "Unknown")
                .font(.subheadline)

            MetadataRow(label: "Bit Depth", value: asset.bitDepth ?? "Unknown")
                .font(.subheadline)

            Divider().padding(.vertical, 2)

            // Audio information
            MetadataRow(label: "Audio Codec", value: asset.audioCodec ?? "Unknown")
                .font(.subheadline)

            MetadataRow(label: "Channels", value: asset.audioChannels ?? "Unknown")
                .font(.subheadline)

            if asset.audioSampleRate > 0 {
                MetadataRow(label: "Sample Rate", value: String(format: "%.1f kHz", Float(asset.audioSampleRate) / 1000.0))
                    .font(.subheadline)
            }

            Divider().padding(.vertical, 2)

            MetadataRow(label: "Created", value: formattedDate(asset.creationDate))
                .font(.subheadline)

            MetadataRow(label: "Edited", value: formattedDate(asset.lastEditDate))
                .font(.subheadline)

        }
    }
    
    // --- Formatters ---
    
    private func formattedDuration(_ duration: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(duration)) ?? "00:00"
    }
    
    private func formattedSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func formattedBitrate(_ bitrate: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        // Convert bits per second to bytes per second for the formatter
        let bytesPerSecond = bitrate / 8
        return formatter.string(fromByteCount: bytesPerSecond) + "/s" // e.g., "10 MB/s"
    }
    
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedResolution(width: Int32, height: Int32) -> String {
        guard width > 0 && height > 0 else { return "Unknown" }

        let resolutionString = "\(width)x\(height)"

        // Add common resolution names
        switch (width, height) {
        case (3840, 2160):
            return "\(resolutionString) (4K UHD)"
        case (4096, 2160):
            return "\(resolutionString) (4K DCI)"
        case (1920, 1080):
            return "\(resolutionString) (1080p)"
        case (1280, 720):
            return "\(resolutionString) (720p)"
        case (7680, 4320):
            return "\(resolutionString) (8K)"
        case (2560, 1440):
            return "\(resolutionString) (1440p)"
        default:
            return resolutionString
        }
    }
}

// Helper subview for metadata alignment
struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .frame(width: 80, alignment: .leading)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(value)
        }
    }
}

// Helper subview for metadata with estimated values
struct MetadataRowWithEstimate: View {
    let label: String
    let originalValue: String
    let estimatedValue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label + ":")
                .frame(width: 80, alignment: .leading)
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Text(originalValue)
                .foregroundColor(.primary)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.red)

            Text(estimatedValue)
                .foregroundColor(.red)
                .fontWeight(.semibold)
        }
    }
}
