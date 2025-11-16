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

            Group {
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

                MetadataRow(label: "Framerate", value: String(format: "%.2f FPS", asset.frameRate))

                Divider().padding(.vertical, 2)

                // Video codec information
                MetadataRow(label: "Video Codec", value: asset.videoCodec ?? "Unknown")

                MetadataRow(label: "Bit Depth", value: asset.bitDepth ?? "Unknown")

                Divider().padding(.vertical, 2)

                // Audio information
                MetadataRow(label: "Audio Codec", value: asset.audioCodec ?? "Unknown")

                MetadataRow(label: "Channels", value: asset.audioChannels ?? "Unknown")

                if asset.audioSampleRate > 0 {
                    MetadataRow(label: "Sample Rate", value: String(format: "%.1f kHz", Float(asset.audioSampleRate) / 1000.0))
                }

                Divider().padding(.vertical, 2)

                MetadataRow(label: "Created", value: formattedDate(asset.creationDate))

                MetadataRow(label: "Edited", value: formattedDate(asset.lastEditDate))
            }
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
