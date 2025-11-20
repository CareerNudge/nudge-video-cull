//
//  CompactWorkflowView.swift
//  VideoCullingApp
//
//  Compact visual workflow for main content view toolbar
//

import SwiftUI

struct CompactWorkflowView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var hoveredStep: Int? = nil
    @State private var enableFCPXMLExport = false
    @State private var sourceFileCount: Int = 0
    @State private var sourceSpaceGB: Double = 0
    @State private var stagingFileCount: Int = 0
    @State private var stagingSpaceGB: Double = 0
    @State private var outputFileCount: Int = 0
    @State private var outputSpaceGB: Double = 0
    @State private var showSourceCleanup = false
    @State private var showStagingCleanup = false

    var body: some View {
        HStack(spacing: 16) {
            // Workflow nodes (centered with more spacing)
            Spacer()

            HStack(spacing: 14) {
                // Step 1: Source
                CompactWorkflowNode(
                    icon: "folder.badge.plus",
                    iconColor: .blue,
                    title: "Source",
                    subtitle: viewModel.inputFolderURL?.lastPathComponent ?? "Not selected",
                    fileCount: sourceFileCount,
                    spaceGB: sourceSpaceGB,
                    isCompleted: viewModel.inputFolderURL != nil,
                    isHovered: hoveredStep == 1,
                    showCleanupButton: showSourceCleanup,
                    action: {
                        viewModel.selectInputFolder()
                    },
                    cleanupAction: {
                        cleanupSourceFiles()
                    },
                    onHover: { hovering in
                        hoveredStep = hovering ? 1 : nil
                    }
                )

                CompactFlowArrow(isActive: viewModel.inputFolderURL != nil)

                // Step 2: Staging (conditional)
                if let inputURL = viewModel.inputFolderURL, viewModel.isOnExternalMedia(inputURL) {
                    CompactWorkflowNode(
                        icon: "arrow.down.doc.fill",
                        iconColor: .purple,
                        title: "Staging",
                        subtitle: viewModel.stagingFolderURL?.lastPathComponent ?? "Optional",
                        fileCount: stagingFileCount,
                        spaceGB: stagingSpaceGB,
                        isCompleted: viewModel.stagingFolderURL != nil,
                        isHovered: hoveredStep == 2,
                        showCleanupButton: showStagingCleanup,
                        action: {
                            configureStaging()
                        },
                        cleanupAction: {
                            cleanupStagingFiles()
                        },
                        onHover: { hovering in
                            hoveredStep = hovering ? 2 : nil
                        }
                    )
                    .opacity(viewModel.stagingFolderURL != nil ? 1.0 : 0.5)

                    CompactFlowArrow(isActive: true)
                }

                // Step 3: Output
                CompactWorkflowNode(
                    icon: "folder.fill",
                    iconColor: .green,
                    title: "Output",
                    subtitle: viewModel.outputFolderURL?.lastPathComponent ?? "Not selected",
                    fileCount: outputFileCount,
                    spaceGB: outputSpaceGB,
                    isCompleted: viewModel.outputFolderURL != nil,
                    isHovered: hoveredStep == 3,
                    showCleanupButton: false,
                    action: {
                        viewModel.selectOutputFolder()
                    },
                    cleanupAction: {},
                    onHover: { hovering in
                        hoveredStep = hovering ? 3 : nil
                    }
                )

                CompactFlowArrow(isActive: viewModel.outputFolderURL != nil)

                // Step 4: FCPXML (optional)
                CompactWorkflowNode(
                    icon: "film.stack",
                    iconColor: .orange,
                    title: "FCP",
                    subtitle: enableFCPXMLExport ? "On" : "Off",
                    fileCount: nil,
                    spaceGB: nil,
                    isCompleted: enableFCPXMLExport,
                    isHovered: hoveredStep == 4,
                    showCleanupButton: false,
                    action: {
                        enableFCPXMLExport.toggle()
                        UserDefaults.standard.set(enableFCPXMLExport, forKey: "enableFCPXMLExport")
                    },
                    cleanupAction: {},
                    onHover: { hovering in
                        hoveredStep = hovering ? 4 : nil
                    }
                )
                .opacity(enableFCPXMLExport ? 1.0 : 0.5)
            }

            Spacer()

            // Close Folder button
            Button(action: {
                viewModel.closeCurrentFolder()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 20))
                    Text("Close Folder")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .opacity((viewModel.isLoading || viewModel.inputFolderURL == nil) ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading || viewModel.inputFolderURL == nil)
            .help("Close current folder/project")

            // Big process button
            Button(action: {
                viewModel.applyChanges()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                    Text("Process Import/Culling Job")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .opacity(canProcess() ? 1.0 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!canProcess())
        }
        .onAppear {
            updateFileStatistics()
            enableFCPXMLExport = UserDefaults.standard.bool(forKey: "enableFCPXMLExport")
        }
        .onChange(of: viewModel.inputFolderURL) { _ in updateFileStatistics() }
        .onChange(of: viewModel.outputFolderURL) { _ in updateFileStatistics() }
        .onChange(of: viewModel.stagingFolderURL) { _ in updateFileStatistics() }
        .onChange(of: viewModel.processingComplete) { complete in
            if complete {
                // Show cleanup buttons after processing
                showSourceCleanup = viewModel.stagingFolderURL != nil
                showStagingCleanup = viewModel.stagingFolderURL != nil
            }
        }
    }

    private func canProcess() -> Bool {
        return viewModel.inputFolderURL != nil && viewModel.outputFolderURL != nil && !viewModel.isLoading
    }

    private func configureStaging() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select staging folder (local storage recommended)"

        // Start at home directory for staging (typically on local drive)
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.stagingFolderURL = url
            viewModel.saveSecurityScopedBookmark(for: url, key: "stagingFolderBookmark")
        }
    }

    private func updateFileStatistics() {
        Task {
            // Source folder stats
            if let sourceURL = viewModel.inputFolderURL {
                _ = sourceURL.startAccessingSecurityScopedResource()
                let (count, size) = await calculateFolderStats(sourceURL)
                sourceURL.stopAccessingSecurityScopedResource()
                await MainActor.run {
                    sourceFileCount = count
                    sourceSpaceGB = size
                    print("📊 Source stats: \(count) files, \(size) GB")
                }
            }

            // Staging folder stats
            if let stagingURL = viewModel.stagingFolderURL {
                _ = stagingURL.startAccessingSecurityScopedResource()
                let (count, size) = await calculateFolderStats(stagingURL)
                stagingURL.stopAccessingSecurityScopedResource()
                await MainActor.run {
                    stagingFileCount = count
                    stagingSpaceGB = size
                    print("📊 Staging stats: \(count) files, \(size) GB")
                }
            }

            // Output folder stats
            if let outputURL = viewModel.outputFolderURL {
                _ = outputURL.startAccessingSecurityScopedResource()
                let (count, size) = await calculateFolderStats(outputURL)
                outputURL.stopAccessingSecurityScopedResource()
                await MainActor.run {
                    outputFileCount = count
                    outputSpaceGB = size
                    print("📊 Output stats: \(count) files, \(size) GB")
                }
            }
        }
    }

    private func calculateFolderStats(_ url: URL) async -> (count: Int, sizeGB: Double) {
        guard url.startAccessingSecurityScopedResource() else {
            return (0, 0.0)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        var count = 0
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                   let isRegularFile = resourceValues.isRegularFile,
                   isRegularFile {
                    count += 1
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }

        let sizeGB = Double(totalSize) / (1024 * 1024 * 1024)
        return (count, sizeGB)
    }

    private func cleanupSourceFiles() {
        let alert = NSAlert()
        alert.messageText = "Delete Source Files?"
        alert.informativeText = "This will move all files from the source folder to the trash. This action cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Move to Trash")
        alert.alertStyle = .warning

        if alert.runModal() == .alertSecondButtonReturn {
            guard let sourceURL = viewModel.inputFolderURL else { return }
            Task {
                await moveToTrash(sourceURL)
                await updateFileStatistics()
                showSourceCleanup = false
            }
        }
    }

    private func cleanupStagingFiles() {
        let alert = NSAlert()
        alert.messageText = "Delete Staging Files?"
        alert.informativeText = "This will move all files from the staging folder to the trash. This action cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Move to Trash")
        alert.alertStyle = .warning

        if alert.runModal() == .alertSecondButtonReturn {
            guard let stagingURL = viewModel.stagingFolderURL else { return }
            Task {
                await moveToTrash(stagingURL)
                await updateFileStatistics()
                showStagingCleanup = false
            }
        }
    }

    private func moveToTrash(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                try? fileManager.trashItem(at: fileURL, resultingItemURL: nil)
            }
        }
    }
}

// MARK: - Compact Workflow Node Component

struct CompactWorkflowNode: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let fileCount: Int?
    let spaceGB: Double?
    let isCompleted: Bool
    let isHovered: Bool
    let showCleanupButton: Bool
    let action: () -> Void
    let cleanupAction: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Icon, title, and stats in horizontal layout
            Button(action: action) {
                HStack(spacing: 8) {
                    // Icon with completion indicator
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: icon)
                            .font(.system(size: 26))
                            .foregroundColor(isCompleted ? iconColor : iconColor.opacity(0.4))
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isCompleted ? iconColor.opacity(0.15) : iconColor.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isHovered ? iconColor : Color.clear, lineWidth: 2)
                                    )
                            )

                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(iconColor)
                                .background(Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 12, height: 12))
                        }
                    }

                    // Title, subtitle, and stats
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(isCompleted ? iconColor : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        // File count and space inline
                        if let count = fileCount, let space = spaceGB {
                            HStack(spacing: 4) {
                                Text("Files: \(count)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text("Space:")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f GB", space))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                onHover(hovering)
            }

            // Cleanup button
            if showCleanupButton {
                Button(action: cleanupAction) {
                    HStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 8))
                        Text("Clean")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Compact Flow Arrow Component

struct CompactFlowArrow: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<2) { _ in
                Rectangle()
                    .fill(isActive ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(isActive ? .blue : .gray.opacity(0.3))
        }
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController(inMemory: true).container.viewContext
    let viewModel = ContentViewModel(context: context)
    CompactWorkflowView(viewModel: viewModel)
        .frame(height: 120)
        .padding()
}
