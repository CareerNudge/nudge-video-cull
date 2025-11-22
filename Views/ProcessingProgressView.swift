//
//  ProcessingProgressView.swift
//  VideoCullingApp
//

import SwiftUI

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isPresented: Bool
    @State private var showCancelConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var folderToDelete: String = ""
    @State private var folderNameToDelete: String = ""
    @ObservedObject private var tipsManager = TipsManager.shared

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

                // Folder Flow Visualization (only show when complete)
                if viewModel.processingComplete {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            // Source Folder
                            VStack(spacing: 4) {
                                Text("Source")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                if let sourcePath = viewModel.inputFolderURL?.path {
                                    Button(action: {
                                        deleteFolderConfirmation(path: sourcePath, name: "Source")
                                    }) {
                                        Text("Click here to delete this folder")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)

                            // Staging Folder (if used)
                            if let stagingPath = viewModel.stagingFolderURL?.path {
                                VStack(spacing: 4) {
                                    Text("Staging")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)

                                    Button(action: {
                                        deleteFolderConfirmation(path: stagingPath, name: "Staging")
                                    }) {
                                        Text("Click here to delete this folder")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                }

                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                            }

                            // Output Folder
                            VStack(spacing: 4) {
                                Text("Output")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                // No delete option for Output
                                Text("")
                                    .font(.caption2)
                                    .frame(height: 12)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }

                // Tips and How-To's Display (only show while processing)
                if !viewModel.processingComplete, let tip = tipsManager.currentTip {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(tip.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.08))
                        )
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.5), value: tipsManager.currentTip?.id)
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
                            // Reset progress values when dismissing
                            viewModel.processingProgress = 0.0
                            viewModel.currentProcessingFile = ""
                            viewModel.currentFileIndex = 0
                            viewModel.totalFilesToProcess = 0
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
            .onAppear {
                // Start rotating tips when processing view appears
                if !viewModel.processingComplete {
                    tipsManager.startRotation(interval: 7.0)
                }
            }
            .onDisappear {
                // Stop rotating tips when view disappears
                tipsManager.stopRotation()
            }
            .onChange(of: viewModel.processingComplete) { isComplete in
                // Stop tips rotation when processing completes
                if isComplete {
                    tipsManager.stopRotation()
                }
            }
            .alert("Delete \(folderNameToDelete) Folder", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteFolder(path: folderToDelete)
                }
            } message: {
                Text("Are you sure you want to delete the \(folderNameToDelete) folder and all its contents? This action cannot be undone.")
            }
        }
    }

    private func deleteFolderConfirmation(path: String, name: String) {
        folderToDelete = path
        folderNameToDelete = name
        showDeleteConfirmation = true
    }

    private func deleteFolder(path: String) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: path)
            print("✅ Successfully deleted folder: \(path)")

            // Show alert or notification
            let alert = NSAlert()
            alert.messageText = "Folder Deleted"
            alert.informativeText = "The \(folderNameToDelete) folder has been successfully deleted."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            print("❌ Failed to delete folder: \(error)")

            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Delete Failed"
            alert.informativeText = "Could not delete the \(folderNameToDelete) folder: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
