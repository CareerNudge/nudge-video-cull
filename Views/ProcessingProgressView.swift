//
//  ProcessingProgressView.swift
//  VideoCullingApp
//

import SwiftUI

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isPresented: Bool
    @State private var showCancelConfirmation = false

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
                        .foregroundColor(viewModel.processingComplete ? .green : .secondary)
                        .fontWeight(viewModel.processingComplete ? .medium : .regular)
                        .multilineTextAlignment(.center)
                }

                // Button section - changes based on completion state
                if viewModel.processingComplete {
                    // Show FCPXML Export and Done buttons when complete
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.exportFCPXML()
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Export to FCPXML")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            isPresented = false
                            viewModel.processingComplete = false
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Show Cancel button while processing
                    Button(action: {
                        showCancelConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: viewModel.isCancelling ? "hourglass" : "xmark.circle.fill")
                            Text(viewModel.isCancelling ? "Cancelling..." : "Cancel Job")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.isCancelling ? Color.gray : Color.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isCancelling)
                    .alert("Cancel Processing", isPresented: $showCancelConfirmation) {
                        Button("Continue Processing", role: .cancel) { }
                        Button("Cancel Job", role: .destructive) {
                            viewModel.cancelProcessing()
                        }
                    } message: {
                        Text("Are you sure you want to cancel? Any partial progress will be lost and incomplete files may remain in the output folder.")
                    }
                }
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
}
