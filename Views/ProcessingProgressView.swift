//
//  ProcessingProgressView.swift
//  VideoCullingApp
//

import SwiftUI

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 24) {
                // Title
                Text("Processing Videos")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Current file info
                if !viewModel.currentProcessingFile.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current File:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(viewModel.currentProcessingFile)
                            .font(.body)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(.linear)
                        .frame(height: 8)

                    HStack {
                        Text("\(viewModel.currentFileIndex) of \(viewModel.totalFilesToProcess)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(viewModel.processingProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Status message
                if !viewModel.loadingStatus.isEmpty && viewModel.loadingStatus != "Idle" {
                    Text(viewModel.loadingStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Cancel button
                Button(action: {
                    cancelProcessing()
                }) {
                    Text("Cancel Job")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
        }
    }

    private func cancelProcessing() {
        // TODO: Implement cancellation logic
        isPresented = false
    }
}
