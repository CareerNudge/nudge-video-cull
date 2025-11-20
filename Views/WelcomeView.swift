//
//  WelcomeView.swift
//  VideoCullingApp
//
//  Interactive workflow setup screen - ALWAYS SHOWN
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: ContentViewModel
    @State private var showCullInPlaceWarning = false
    @State private var showDestinationAlert = false
    @State private var enableFCPXMLExport = false
    @State private var hoveredStep: Int? = nil

    // Track which steps are completed
    @State private var sourceSelected = false
    @State private var stagingConfigured = false
    @State private var outputSelected = false

    // Beta expiration date: April 1, 2026
    private var betaExpirationDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    private var isBetaExpired: Bool {
        return Date() >= betaExpirationDate
    }

    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Welcome card
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.waveform.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Nudge Video Cull")
                        .font(.system(size: 28, weight: .bold))

                    Text("Configure your workflow")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                .padding(.bottom, 24)

                Divider()

                // Interactive workflow diagram
                VStack(spacing: 20) {
                    Text("Click each step to configure")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)

                    // Visual flow diagram
                    HStack(spacing: 0) {
                        // Step 1: Source Selection
                        InteractiveWorkflowStep(
                            number: 1,
                            icon: "folder.badge.plus",
                            iconColor: .blue,
                            title: "Source Media",
                            subtitle: viewModel.inputFolderURL?.lastPathComponent ?? "Not selected",
                            isCompleted: viewModel.inputFolderURL != nil,
                            isHovered: hoveredStep == 1,
                            action: {
                                selectSourceFolder()
                            },
                            onHover: { hovering in
                                hoveredStep = hovering ? 1 : nil
                            }
                        )
                        .accessibilityIdentifier("sourceNodeButton")

                        // Arrow
                        FlowArrow(isActive: viewModel.inputFolderURL != nil)

                        // Step 2: Staging (conditional - only show if external media detected)
                        if let inputURL = viewModel.inputFolderURL, viewModel.isOnExternalMedia(inputURL) {
                            InteractiveWorkflowStep(
                                number: 2,
                                icon: "arrow.down.doc.fill",
                                iconColor: .purple,
                                title: "Staging",
                                subtitle: viewModel.stagingFolderURL?.lastPathComponent ?? "Optional",
                                isCompleted: viewModel.stagingFolderURL != nil,
                                isHovered: hoveredStep == 2,
                                action: {
                                    configureStaging()
                                },
                                onHover: { hovering in
                                    hoveredStep = hovering ? 2 : nil
                                }
                            )

                            FlowArrow(isActive: true)
                        }

                        // Step 3/4: Output Selection
                        InteractiveWorkflowStep(
                            number: (viewModel.inputFolderURL.flatMap { viewModel.isOnExternalMedia($0) } ?? false) ? 3 : 2,
                            icon: "folder.fill",
                            iconColor: .green,
                            title: "Output Folder",
                            subtitle: viewModel.outputFolderURL?.lastPathComponent ?? "Not selected",
                            isCompleted: viewModel.outputFolderURL != nil,
                            isHovered: hoveredStep == 3,
                            action: {
                                selectOutputFolder()
                            },
                            onHover: { hovering in
                                hoveredStep = hovering ? 3 : nil
                            }
                        )
                        .accessibilityIdentifier("outputNodeButton")

                        // Arrow
                        FlowArrow(isActive: viewModel.outputFolderURL != nil)

                        // Step 4/5: FCPXML Export (optional)
                        InteractiveWorkflowStep(
                            number: (viewModel.inputFolderURL.flatMap { viewModel.isOnExternalMedia($0) } ?? false) ? 4 : 3,
                            icon: "film.stack",
                            iconColor: .orange,
                            title: "FCP Export",
                            subtitle: enableFCPXMLExport ? "Enabled" : "Optional",
                            isCompleted: enableFCPXMLExport,
                            isHovered: hoveredStep == 4,
                            action: {
                                enableFCPXMLExport.toggle()
                            },
                            onHover: { hovering in
                                hoveredStep = hovering ? 4 : nil
                            }
                        )
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }

                Divider()

                // Bottom section with GO button
                VStack(spacing: 16) {
                    Text("Ready to start?")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.top, 20)

                    // Single GO button
                    Button(action: {
                        handleGoButton()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                            Text("GO!")
                                .font(.system(size: 22, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .opacity(canProceed() ? 1.0 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canProceed())
                    .accessibilityIdentifier("goButton")
                    .padding(.horizontal, 30)

                    // Scanning progress indicator
                    if isBetaExpired {
                        // Show beta expiration message
                        Text("Beta version only valid until April 2026")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.bottom, 16)
                    } else if viewModel.isLoading {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text(viewModel.loadingStatus)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            if viewModel.totalFilesToProcess > 0 {
                                HStack(spacing: 8) {
                                    ProgressView(value: viewModel.processingProgress)
                                        .frame(width: 200)
                                    Text("\(viewModel.currentFileIndex)/\(viewModel.totalFilesToProcess) files")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    } else if !allRequiredFieldsConfigured() {
                        Text("Configure source and output folders to begin")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 16)
                    } else {
                        Text("✓ Ready to begin")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .padding(.bottom, 16)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(width: 950, height: 520)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
        }
        .alert("Culling In Place Warning", isPresented: $showCullInPlaceWarning) {
            Button("Add Different Destination", role: .cancel) {
                showCullInPlaceWarning = false
                selectOutputFolder()
            }
            Button("Proceed with Culling in Place", role: .destructive) {
                viewModel.setCullInPlaceMode()
                startWorkflow()
            }
        } message: {
            Text("This will perform culling of the source data where it currently resides. This will result in data loss:\n\n• Files flagged for deletion will be moved to trash\n• Trimmed files: original moved to trash, trimmed version remains\n\nThis is not reversible. Proceed?")
        }
    }

    // MARK: - Helper Methods

    private func allRequiredFieldsConfigured() -> Bool {
        // Ensure folders are selected (scanning will happen after GO is clicked)
        return viewModel.inputFolderURL != nil &&
               viewModel.outputFolderURL != nil
    }

    private func canProceed() -> Bool {
        // Check both required fields and beta expiration
        return !isBetaExpired && allRequiredFieldsConfigured()
    }

    private func handleGoButton() {
        guard let inputURL = viewModel.inputFolderURL,
              let outputURL = viewModel.outputFolderURL else {
            return
        }

        // Check if output folder is the same as source
        let isSameFolder = inputURL.path == outputURL.path

        if isSameFolder {
            // Show culling in place warning when folders are the same
            showCullInPlaceWarning = true
        } else {
            // Proceed with import mode when folders are different
            viewModel.setImportMode()
            startWorkflow()
        }
    }

    private func selectSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select source media folder"

        // Set initial directory based on user preferences
        let preferences = UserPreferences.shared
        if preferences.defaultSourceFolder == .customPath && !preferences.customSourcePath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: preferences.customSourcePath)
        } else if preferences.defaultSourceFolder == .lastUsed {
            // First check saved path string in preferences
            if !preferences.lastUsedInputPath.isEmpty {
                panel.directoryURL = URL(fileURLWithPath: preferences.lastUsedInputPath)
            } else if let lastUsed = viewModel.inputFolderURL {
                // Fall back to current state if no saved path
                panel.directoryURL = lastUsed
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.inputFolderURL = url

            // Save the path to preferences for future folder selections
            preferences.lastUsedInputPath = url.path

            viewModel.saveSecurityScopedBookmark(for: url, key: "lastInputFolderBookmark")

            // Don't scan yet - wait for user to click GO
            print("   ℹ️ Source folder selected, scanning deferred until GO is clicked")

            // Check for external media
            if viewModel.isOnExternalMedia(url) {
                // Only show alert if user wants to be asked
                let preferences = UserPreferences.shared
                if preferences.askAboutStaging {
                    // Offer staging
                    let alert = NSAlert()
                    alert.messageText = "External Media Detected"
                    alert.informativeText = "This folder is on external media. Would you like to stage files locally for better performance?"
                    alert.addButton(withTitle: "Configure Staging")
                    alert.addButton(withTitle: "Skip")
                    alert.addButton(withTitle: "Don't ask any more")
                    alert.alertStyle = .informational

                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        configureStaging()
                    } else if response == .alertThirdButtonReturn {
                        // Don't ask any more
                        preferences.askAboutStaging = false
                    }
                }
            }
        }
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

    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select output folder for processed videos"

        // Set initial directory based on user preferences
        let preferences = UserPreferences.shared
        if preferences.defaultDestinationFolder == .customPath && !preferences.customDestinationPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: preferences.customDestinationPath)
        } else if preferences.defaultDestinationFolder == .lastUsed {
            // First check saved path string in preferences
            if !preferences.lastUsedOutputPath.isEmpty {
                panel.directoryURL = URL(fileURLWithPath: preferences.lastUsedOutputPath)
            } else if let lastUsed = viewModel.outputFolderURL {
                // Fall back to current state if no saved path
                panel.directoryURL = lastUsed
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.outputFolderURL = url

            // Save the path to preferences for future folder selections
            preferences.lastUsedOutputPath = url.path

            viewModel.saveSecurityScopedBookmark(for: url, key: "lastOutputFolderBookmark")
        }
    }

    private func startWorkflow() {
        // Store FCPXML export preference
        UserDefaults.standard.set(enableFCPXMLExport, forKey: "enableFCPXMLExport")

        // Close welcome screen
        isPresented = false

        // NOW start scanning after user clicked GO
        Task {
            await viewModel.scanInputFolder()
        }
    }
}

// MARK: - Interactive Workflow Step Component
struct InteractiveWorkflowStep: View {
    let number: Int
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let isHovered: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Step number badge with completion indicator
                ZStack {
                    Circle()
                        .fill(isCompleted ? iconColor : iconColor.opacity(0.2))
                        .frame(width: 28, height: 28)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(number)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(iconColor)
                    }
                }

                // Icon
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(isCompleted ? iconColor : iconColor.opacity(0.5))
                }
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCompleted ? iconColor.opacity(0.15) : iconColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isHovered ? iconColor : Color.clear, lineWidth: 2)
                        )
                )

                // Text content
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isCompleted ? iconColor : .secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .frame(width: 120)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHovered ? Color.gray.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

// MARK: - Flow Arrow Component
struct FlowArrow: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { _ in
                Rectangle()
                    .fill(isActive ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? .blue : .gray.opacity(0.3))
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview
#Preview {
    let context = PersistenceController(inMemory: true).container.viewContext
    let viewModel = ContentViewModel(context: context)
    WelcomeView(isPresented: .constant(true), viewModel: viewModel)
}
