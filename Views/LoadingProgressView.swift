//
//  LoadingProgressView.swift
//  VideoCullingApp
//

import SwiftUI

struct LoadingProgressView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Analyzing Videos")
                .font(.title)
                .fontWeight(.bold)

            Divider()

            // Current operation status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Operation:")
                    .font(.headline)

                Text(viewModel.loadingStatus)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Progress bar
            if viewModel.totalFilesToProcess > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress:")
                            .font(.headline)

                        Spacer()

                        Text("\(viewModel.currentFileIndex) of \(viewModel.totalFilesToProcess)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(.linear)
                }
            }

            // Current file being processed
            if !viewModel.currentProcessingFile.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currently Analyzing:")
                        .font(.headline)

                    Text(viewModel.currentProcessingFile)
                        .font(.body)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Analysis details
            VStack(alignment: .leading, spacing: 12) {
                Text("Analysis includes:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Video codec, resolution, and frame rate")
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Audio channels and sample rate")
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Camera metadata (gamma, color space)")
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Automatic LUT mapping")
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Thumbnail generation")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )

            Divider()

            // Destination folder selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Output Destination:")
                    .font(.headline)

                HStack {
                    if let outputURL = viewModel.outputFolderURL {
                        Text(outputURL.lastPathComponent)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No destination selected (in-place processing)")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    Spacer()

                    Button("Choose Destination...") {
                        viewModel.selectOutputFolder()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )

            Spacer()

            // Close button (only show when not loading)
            if !viewModel.isLoading {
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 600, height: 550)
    }
}
