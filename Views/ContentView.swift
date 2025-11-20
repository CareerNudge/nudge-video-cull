//
//  ContentView.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // 1. View model for handling state and logic
    @StateObject private var viewModel: ContentViewModel
    @ObservedObject private var lutManager = LUTManager.shared
    @State private var showLUTManager = false
    @State private var showPreferences = false
    @State private var showLoadingProgress = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = false
    @State private var showCullInPlaceConfirmation = false

    init() {
        // Initialize the StateObject with the persistence controller
        // This is a way to inject the context into the @StateObject
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: ContentViewModel(context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- TOP TOOLBAR ---
            VStack(spacing: 8) {
                // Compact workflow visualization with process button
                HStack {
                    CompactWorkflowView(viewModel: viewModel)

                    Spacer()

                    // Preferences Button (styled to match Process button height)
                    Button(action: {
                        showPreferences = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                            Text("Preferences")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .help("Open application preferences")
                    .keyboardShortcut(",", modifiers: .command)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Divider()

                // SECOND ROW: Sort Order, Global LUT, Status
                HStack {
                    // Sort Order Picker
                    HStack(spacing: 8) {
                        Text("Sort Order:")
                            .font(.subheadline)

                        Picker("", selection: $viewModel.sortOrder) {
                            ForEach(ContentViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 8)

                    // Global LUT Selector
                    HStack(spacing: 8) {
                        Text("Preview all videos with LUT:")
                            .font(.subheadline)

                        Picker("", selection: $lutManager.globalSelectedLUT) {
                            Text("None").tag(nil as LUT?)
                            ForEach(lutManager.availableLUTs) { lut in
                                Text(lut.name).tag(lut as LUT?)
                            }
                        }
                        .frame(width: 150)
                        .onChange(of: lutManager.globalSelectedLUT) { newLUT in
                            viewModel.applyGlobalLUT(newLUT)
                        }
                    }

                    Spacer()

                    // --- PROCESSING STATUS LOGIC ---
                    if viewModel.isLoading && !viewModel.showProcessingModal {
                        // Only show inline spinner for scanning mode
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text(viewModel.loadingStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if !viewModel.loadingStatus.isEmpty && viewModel.loadingStatus != "Idle" {
                        // Show status when not idle or processing
                        Text(viewModel.loadingStatus)
                            .font(.subheadline)
                            .foregroundColor(viewModel.processingComplete ? .green : .secondary)
                            .fontWeight(viewModel.processingComplete ? .medium : .regular)
                    }
                    // --- END PROCESSING LOGIC ---

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.bar)

            Divider()

            // --- MAIN GALLERY ---
            GalleryView()
        }
        .frame(minWidth: 1400, minHeight: 700)
        .overlay {
            // Processing Progress Modal
            if viewModel.showProcessingModal {
                ProcessingProgressView(viewModel: viewModel, isPresented: $viewModel.showProcessingModal)
            }

            // Welcome Modal
            if showWelcome {
                WelcomeView(isPresented: $showWelcome, viewModel: viewModel)
            }
        }
        .onAppear {
            // Apply theme preference
            applyTheme()

            if !ProcessInfo.processInfo.arguments.contains("-disableWelcomeScreen") {
                showWelcome = true
            }
        }
        .onChange(of: UserPreferences.shared.theme) { _ in
            // Apply theme when it changes
            applyTheme()
        }
        .onChange(of: showWelcome) { isShowing in
            // When welcome popup is dismissed (and it was shown), highlight the input folder button
            if !isShowing && !hasSeenWelcome {
                viewModel.highlightInputFolderButton = true

                // Auto-dismiss highlight after 8 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    viewModel.highlightInputFolderButton = false
                }
            }
        }
        .sheet(isPresented: $showLUTManager) {
            LUTManagerView(lutManager: lutManager)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showLoadingProgress) {
            LoadingProgressView(viewModel: viewModel, isPresented: $showLoadingProgress)
        }
        // Note: Removed automatic loading progress modal - progress now shown in welcome screen
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("External Media Detected", isPresented: $viewModel.showExternalMediaAlert) {
            Button("No - Work off external media", role: .cancel) {
                viewModel.proceedWithoutStaging()
            }
            Button("Yes - Stage locally", role: .none) {
                viewModel.proceedWithStaging()
            }
            Button("Don't ask any more") {
                UserPreferences.shared.askAboutStaging = false
                viewModel.proceedWithoutStaging()
            }
        } message: {
            Text("Previewing and editing directly from external media may result in a choppy experience. Would you like to first stage the media locally as a pre-step?")
        }
        .overlay {
            // Staging progress modal
            if viewModel.isStaging {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 24) {
                        Text("Staging Media Locally")
                            .font(.title)
                            .fontWeight(.bold)

                        Divider()

                        Text(viewModel.stagingStatus)
                            .font(.body)
                            .foregroundColor(.secondary)

                        ProgressView(value: viewModel.stagingProgress)
                            .progressViewStyle(.linear)

                        Text("\(Int(viewModel.stagingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .frame(width: 500)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(radius: 30)
                    )
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func canProcess() -> Bool {
        // Must have input folder
        guard viewModel.inputFolderURL != nil else {
            return false
        }

        // In import mode, must also have output folder
        if viewModel.workflowMode == .importMode {
            return viewModel.outputFolderURL != nil
        }

        // In cull in place mode, only need input folder
        return true
    }

    private func processButtonTooltip() -> String {
        if viewModel.inputFolderURL == nil {
            return "Select an input folder first"
        }

        if viewModel.workflowMode == .importMode && viewModel.outputFolderURL == nil {
            return "Import mode requires selecting an output folder"
        }

        return viewModel.testMode ? "Run test export to output folder" : "Process all videos with selected settings"
    }

    private func processButtonText() -> String {
        if viewModel.testMode {
            return "Test Export"
        }

        switch viewModel.workflowMode {
        case .importMode:
            return "Process and Import Videos"
        case .cullInPlace:
            return "Delete Flagged Files"
        }
    }

    private func processButtonIcon() -> String {
        switch viewModel.workflowMode {
        case .importMode:
            return "play.circle.fill"
        case .cullInPlace:
            return "trash.circle.fill"
        }
    }

    private func processButtonTint() -> Color {
        if viewModel.testMode {
            return .orange
        }

        switch viewModel.workflowMode {
        case .importMode:
            return .green
        case .cullInPlace:
            return .red
        }
    }

    private func applyTheme() {
        let preferences = UserPreferences.shared

        switch preferences.theme {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .followSystem:
            NSApp.appearance = nil  // Use system setting
        }
    }
}
