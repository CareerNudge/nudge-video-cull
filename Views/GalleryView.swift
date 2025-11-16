//
//  GalleryView.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData

struct GalleryView: View {
    // 1. Fetch all assets, sort by file path.
    // This @FetchRequest is the "ViewModel" for this list.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ManagedVideoAsset.filePath, ascending: true)],
        animation: .default)
    private var videoAssets: FetchedResults<ManagedVideoAsset>

    // Calculate statistics
    private var statistics: (totalClips: Int, originalDuration: Double, estimatedDuration: Double, originalSize: Double, estimatedSize: Double) {
        let totalClips = videoAssets.count
        var originalDuration = 0.0
        var estimatedDuration = 0.0
        var originalSize = 0.0
        var estimatedSize = 0.0

        for asset in videoAssets {
            originalDuration += asset.duration
            originalSize += Double(asset.fileSize)

            // Calculate estimated duration after trim
            let trimStart = asset.trimStartTime
            let trimEnd = asset.trimEndTime > 0 ? asset.trimEndTime : 1.0
            let trimmedDuration = asset.duration * (trimEnd - trimStart)
            estimatedDuration += trimmedDuration

            // Estimate size proportionally to duration
            let sizeRatio = trimmedDuration / asset.duration
            estimatedSize += Double(asset.fileSize) * sizeRatio
        }

        return (totalClips, originalDuration, estimatedDuration, originalSize, estimatedSize)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sticky Header
            if !videoAssets.isEmpty {
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        // Preview and Trim column
                        Text("Preview and Trim")
                            .font(.headline)
                            .frame(width: 400, alignment: .leading)
                            .padding(.leading, 28)

                        // Video Import Settings column
                        Text("Video Import Settings")
                            .font(.headline)
                            .frame(maxWidth: 350, alignment: .leading)

                        // Clip Meta Data column
                        Text("Clip Meta Data")
                            .font(.headline)
                            .frame(width: 200, alignment: .leading)

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()
                }
            }

            // Main content with ScrollView
            ScrollView {
                LazyVStack(spacing: 16) {
                    if videoAssets.isEmpty {
                        Text("Select a folder to begin.")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .padding(.top, 100)
                    } else {
                        ForEach(videoAssets) { asset in
                            VStack(spacing: 0) {
                                VideoAssetRowView(asset: asset)
                                    .padding(.top, 20)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            // Sticky Footer
            if !videoAssets.isEmpty {
                VStack(spacing: 0) {
                    Divider()

                    HStack(spacing: 32) {
                        // Total Clips
                        HStack(spacing: 8) {
                            Text("Total Clips:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(statistics.totalClips)")
                                .font(.subheadline.bold())
                        }

                        // Total Duration
                        HStack(spacing: 8) {
                            Text("Total Duration:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatDuration(statistics.originalDuration)) → \(formatDuration(statistics.estimatedDuration))")
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedDuration < statistics.originalDuration ? .green : .primary)
                        }

                        // Total File Size
                        HStack(spacing: 8) {
                            Text("Total File Size:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatFileSize(statistics.originalSize)) → \(formatFileSize(statistics.estimatedSize))")
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedSize < statistics.originalSize ? .green : .primary)
                        }

                        Spacer()

                        // Total Space Savings (far right)
                        HStack(spacing: 8) {
                            Text("Total Space Savings:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatFileSize(max(0, statistics.originalSize - statistics.estimatedSize)))
                                .font(.subheadline.bold())
                                .foregroundColor(statistics.estimatedSize < statistics.originalSize ? .green : .orange)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
    }

    // Helper function to format duration
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // Helper function to format file size
    private func formatFileSize(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
