//
//  PreferencesView.swift
//  VideoCullingApp
//

import SwiftUI

// MARK: - User Preferences Model
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    // Default Folders
    @Published var defaultSourceFolder: DefaultFolderOption = .lastUsed {
        didSet { UserDefaults.standard.set(defaultSourceFolder.rawValue, forKey: "defaultSourceFolder") }
    }

    @Published var defaultDestinationFolder: DefaultFolderOption = .lastUsed {
        didSet { UserDefaults.standard.set(defaultDestinationFolder.rawValue, forKey: "defaultDestinationFolder") }
    }

    @Published var customSourcePath: String = "" {
        didSet { UserDefaults.standard.set(customSourcePath, forKey: "customSourcePath") }
    }

    @Published var customDestinationPath: String = "" {
        didSet { UserDefaults.standard.set(customDestinationPath, forKey: "customDestinationPath") }
    }

    // Last Used Folder Paths (for display in preferences)
    @Published var lastUsedInputPath: String = "" {
        didSet { UserDefaults.standard.set(lastUsedInputPath, forKey: "lastUsedInputPath") }
    }

    @Published var lastUsedOutputPath: String = "" {
        didSet { UserDefaults.standard.set(lastUsedOutputPath, forKey: "lastUsedOutputPath") }
    }

    // Video Play-Through
    @Published var videoPlayThroughEnabled: Bool = false {
        didSet { UserDefaults.standard.set(videoPlayThroughEnabled, forKey: "videoPlayThroughEnabled") }
    }

    // Apply Default LUTs to Preview
    @Published var applyDefaultLUTsToPreview: Bool = true {
        didSet { UserDefaults.standard.set(applyDefaultLUTsToPreview, forKey: "applyDefaultLUTsToPreview") }
    }

    // Ask About Staging for External Media
    @Published var askAboutStaging: Bool = true {
        didSet { UserDefaults.standard.set(askAboutStaging, forKey: "askAboutStaging") }
    }

    // Theme
    @Published var theme: ThemeOption = .followSystem {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    // Orientation
    @Published var orientation: OrientationOption = .horizontal {
        didSet { UserDefaults.standard.set(orientation.rawValue, forKey: "orientation") }
    }

    // Test Mode
    @Published var testMode: Bool = false {
        didSet { UserDefaults.standard.set(testMode, forKey: "testMode") }
    }

    // Naming Convention
    @Published var defaultNamingConvention: String = "none" {
        didSet { UserDefaults.standard.set(defaultNamingConvention, forKey: "defaultNamingConvention") }
    }

    // Workflow Mode
    @Published var workflowMode: WorkflowModeOption = .importMode {
        didSet { UserDefaults.standard.set(workflowMode.rawValue, forKey: "workflowMode") }
    }

    // Hotkeys (stored as key codes and character strings)
    @Published var hotkeyNavigateNextCode: UInt16 = 124 { // Right Arrow
        didSet { UserDefaults.standard.set(Int(hotkeyNavigateNextCode), forKey: "hotkeyNavigateNextCode") }
    }

    @Published var hotkeyNavigatePreviousCode: UInt16 = 123 { // Left Arrow
        didSet { UserDefaults.standard.set(Int(hotkeyNavigatePreviousCode), forKey: "hotkeyNavigatePreviousCode") }
    }

    @Published var hotkeyPlayPauseCode: UInt16 = 49 { // Space
        didSet { UserDefaults.standard.set(Int(hotkeyPlayPauseCode), forKey: "hotkeyPlayPauseCode") }
    }

    @Published var hotkeySetInPoint: String = "a" {
        didSet { UserDefaults.standard.set(hotkeySetInPoint, forKey: "hotkeySetInPoint") }
    }

    @Published var hotkeySetOutPoint: String = "s" {
        didSet { UserDefaults.standard.set(hotkeySetOutPoint, forKey: "hotkeySetOutPoint") }
    }

    @Published var hotkeyToggleDeletion: String = "d" {
        didSet { UserDefaults.standard.set(hotkeyToggleDeletion, forKey: "hotkeyToggleDeletion") }
    }

    @Published var hotkeyResetTrimPoints: String = "f" {
        didSet { UserDefaults.standard.set(hotkeyResetTrimPoints, forKey: "hotkeyResetTrimPoints") }
    }

    private init() {
        loadPreferences()
    }

    private func loadPreferences() {
        if let sourceFolderRaw = UserDefaults.standard.string(forKey: "defaultSourceFolder"),
           let sourceFolder = DefaultFolderOption(rawValue: sourceFolderRaw) {
            defaultSourceFolder = sourceFolder
        }

        if let destFolderRaw = UserDefaults.standard.string(forKey: "defaultDestinationFolder"),
           let destFolder = DefaultFolderOption(rawValue: destFolderRaw) {
            defaultDestinationFolder = destFolder
        }

        customSourcePath = UserDefaults.standard.string(forKey: "customSourcePath") ?? ""
        customDestinationPath = UserDefaults.standard.string(forKey: "customDestinationPath") ?? ""

        lastUsedInputPath = UserDefaults.standard.string(forKey: "lastUsedInputPath") ?? ""
        lastUsedOutputPath = UserDefaults.standard.string(forKey: "lastUsedOutputPath") ?? ""

        videoPlayThroughEnabled = UserDefaults.standard.bool(forKey: "videoPlayThroughEnabled")
        applyDefaultLUTsToPreview = UserDefaults.standard.object(forKey: "applyDefaultLUTsToPreview") as? Bool ?? true
        askAboutStaging = UserDefaults.standard.object(forKey: "askAboutStaging") as? Bool ?? true

        if let themeRaw = UserDefaults.standard.string(forKey: "theme"),
           let theme = ThemeOption(rawValue: themeRaw) {
            self.theme = theme
        }

        if let orientationRaw = UserDefaults.standard.string(forKey: "orientation"),
           let orientation = OrientationOption(rawValue: orientationRaw) {
            self.orientation = orientation
        }

        testMode = UserDefaults.standard.bool(forKey: "testMode")
        defaultNamingConvention = UserDefaults.standard.string(forKey: "defaultNamingConvention") ?? "none"

        if let workflowModeRaw = UserDefaults.standard.string(forKey: "workflowMode"),
           let workflowMode = WorkflowModeOption(rawValue: workflowModeRaw) {
            self.workflowMode = workflowMode
        }

        // Load hotkey preferences
        if let navNext = UserDefaults.standard.object(forKey: "hotkeyNavigateNextCode") as? Int {
            hotkeyNavigateNextCode = UInt16(navNext)
        }
        if let navPrev = UserDefaults.standard.object(forKey: "hotkeyNavigatePreviousCode") as? Int {
            hotkeyNavigatePreviousCode = UInt16(navPrev)
        }
        if let playPause = UserDefaults.standard.object(forKey: "hotkeyPlayPauseCode") as? Int {
            hotkeyPlayPauseCode = UInt16(playPause)
        }
        hotkeySetInPoint = UserDefaults.standard.string(forKey: "hotkeySetInPoint") ?? "a"
        hotkeySetOutPoint = UserDefaults.standard.string(forKey: "hotkeySetOutPoint") ?? "s"
        hotkeyToggleDeletion = UserDefaults.standard.string(forKey: "hotkeyToggleDeletion") ?? "d"
        hotkeyResetTrimPoints = UserDefaults.standard.string(forKey: "hotkeyResetTrimPoints") ?? "f"

        // Migrate old default hotkeys (z, x, c) to new defaults (a, s, d, f)
        migrateOldHotkeys()
    }

    private func migrateOldHotkeys() {
        var needsMigration = false

        // Check if still using old defaults
        if hotkeySetInPoint == "z" {
            hotkeySetInPoint = "a"
            needsMigration = true
        }
        if hotkeySetOutPoint == "x" {
            hotkeySetOutPoint = "s"
            needsMigration = true
        }
        if hotkeyToggleDeletion == "c" {
            hotkeyToggleDeletion = "d"
            needsMigration = true
        }

        if needsMigration {
            print("🔄 Migrated old hotkeys (Z, X, C) to new defaults (A, S, D, F)")
        }
    }

    enum DefaultFolderOption: String, CaseIterable {
        case lastUsed = "Last Used"
        case customPath = "Choose a Default Path"
    }

    enum ThemeOption: String, CaseIterable {
        case dark = "Dark"
        case light = "Light"
        case followSystem = "Follow Computer Settings"
    }

    enum OrientationOption: String, CaseIterable {
        case vertical = "Vertical"
        case horizontal = "Horizontal"
    }

    enum WorkflowModeOption: String, CaseIterable {
        case importMode = "Import Mode"
        case cullInPlace = "Cull In Place"

        var description: String {
            switch self {
            case .importMode:
                return "Copy and process videos from input to output folder. Original files remain untouched."
            case .cullInPlace:
                return "Delete unwanted files from input folder. Destructive operation - use with caution!"
            }
        }
    }
}

// MARK: - Preferences View
struct PreferencesView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @ObservedObject private var lutManager = LUTManager.shared
    @State private var showingLUTManager = false
    @Environment(\.dismiss) var dismiss
    @State private var selectedSection: PreferenceSection = .general

    enum PreferenceSection: String, CaseIterable, Identifiable {
        case general = "General"
        case hotkeys = "Hotkeys"
        case appearance = "Appearance"
        case advanced = "Advanced"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .hotkeys: return "keyboard"
            case .appearance: return "paintbrush"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(PreferenceSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                        .font(.body)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .navigationTitle("Settings")
        } detail: {
            // Detail view
            VStack(spacing: 0) {
                // Content area with proper padding and styling
                Group {
                    switch selectedSection {
                    case .general:
                        GeneralPreferencesView(preferences: preferences)
                    case .hotkeys:
                        HotkeyPreferencesView(preferences: preferences)
                    case .appearance:
                        AppearancePreferencesView(preferences: preferences)
                    case .advanced:
                        AdvancedPreferencesView(preferences: preferences, lutManager: lutManager, showingLUTManager: $showingLUTManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Bottom toolbar
                HStack {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
            .navigationTitle(selectedSection.rawValue)
        }
        .frame(width: 800, height: 550)
        .sheet(isPresented: $showingLUTManager) {
            LUTManagerView(lutManager: lutManager)
        }
    }
}

// MARK: - General Preferences
struct GeneralPreferencesView: View {
    @ObservedObject var preferences: UserPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section: Default Folders
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Folders")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                // Source Folder
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Source Folder:")
                            .frame(width: 200, alignment: .leading)

                        Picker("", selection: $preferences.defaultSourceFolder) {
                            ForEach(UserPreferences.DefaultFolderOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .frame(width: 250)
                        .help("'Last Used' remembers the last source folder you opened (tracked separately from destination folder). 'Choose a Default Path' lets you set a permanent default source folder.")
                    }

                    if preferences.defaultSourceFolder == .customPath {
                        HStack {
                            TextField("Path", text: $preferences.customSourcePath)
                                .disabled(true)
                            Button("Choose...") {
                                selectCustomSourceFolder()
                            }
                        }
                        .padding(.leading, 200)
                    }
                }

                Divider()

                // Destination Folder
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Destination Folder:")
                            .frame(width: 200, alignment: .leading)

                        Picker("", selection: $preferences.defaultDestinationFolder) {
                            ForEach(UserPreferences.DefaultFolderOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .frame(width: 250)
                        .help("'Last Used' remembers the last destination folder you selected (tracked separately from source folder). 'Choose a Default Path' lets you set a permanent default destination folder.")
                    }

                    if preferences.defaultDestinationFolder == .customPath {
                        HStack {
                            TextField("Path", text: $preferences.customDestinationPath)
                                .disabled(true)
                            Button("Choose...") {
                                selectCustomDestinationFolder()
                            }
                        }
                        .padding(.leading, 200)
                    }
                }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Last Used Folders (Read-Only)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last Used Folders")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                        // Last Used Source
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Last Used Source:")
                                    .frame(width: 200, alignment: .leading)
                                    .foregroundColor(.secondary)

                                TextField("", text: .constant(preferences.lastUsedInputPath.isEmpty ? "No folder used yet" : preferences.lastUsedInputPath))
                                    .textFieldStyle(.plain)
                                    .disabled(true)
                                    .foregroundColor(preferences.lastUsedInputPath.isEmpty ? .secondary : .primary)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                        }

                        Divider()

                        // Last Used Destination
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Last Used Destination:")
                                    .frame(width: 200, alignment: .leading)
                                    .foregroundColor(.secondary)

                                TextField("", text: .constant(preferences.lastUsedOutputPath.isEmpty ? "No folder used yet" : preferences.lastUsedOutputPath))
                                    .textFieldStyle(.plain)
                                    .disabled(true)
                                    .foregroundColor(preferences.lastUsedOutputPath.isEmpty ? .secondary : .primary)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Playback
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playback")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                        // Video Play-Through
                        HStack(alignment: .top) {
                            Toggle("Video Play-Through", isOn: $preferences.videoPlayThroughEnabled)
                                .frame(width: 200, alignment: .leading)
                                .help("When enabled, videos will automatically advance to the next video after playback completes (with a 2-second delay)")

                            VStack(alignment: .leading, spacing: 4) {
                                if preferences.videoPlayThroughEnabled {
                                    Text("Enabled")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                }
                                Text("When enabled, videos automatically advance to the next clip after playback completes. There's a 2-second delay between clips, giving you time to make edits before moving on.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Divider()

                        // Ask About Staging
                        HStack(alignment: .top) {
                            Toggle("Ask About Staging", isOn: $preferences.askAboutStaging)
                                .frame(width: 200, alignment: .leading)
                                .help("When enabled, you'll be prompted to use local staging when selecting folders on external media")

                            VStack(alignment: .leading, spacing: 4) {
                                if !preferences.askAboutStaging {
                                    Text("Disabled")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fontWeight(.semibold)
                                }
                                Text("When enabled, you'll be prompted about staging files locally when selecting source folders on external media (USB drives, SD cards, etc.). Disable this to always work directly from external media without prompting.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Default Naming Convention
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Naming Convention")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Re-Naming:")
                                .frame(width: 200, alignment: .leading)

                            Picker("", selection: $preferences.defaultNamingConvention) {
                                Text("None").tag("none")
                                Text("YYYYMMDD-[Original Name]").tag("datePrefix")
                                Text("[Original Name]-YYYYMMDD").tag("dateSuffix")
                                Text("YYYYMMDD-HHMMSS-[Original Name]").tag("dateTimePrefix")
                            }
                            .frame(width: 300)
                            .help("Choose a default naming convention to apply to all imported videos")
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func selectCustomSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            preferences.customSourcePath = url.path
        }
    }

    private func selectCustomDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            preferences.customDestinationPath = url.path
        }
    }
}

// MARK: - Appearance Preferences
struct AppearancePreferencesView: View {
    @ObservedObject var preferences: UserPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section: Theme
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Appearance:")
                                .frame(width: 200, alignment: .leading)

                            Picker("", selection: $preferences.theme) {
                                ForEach(UserPreferences.ThemeOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .frame(width: 250)
                            .help("Choose between Dark, Light, or follow your computer's system settings")
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Layout
                VStack(alignment: .leading, spacing: 12) {
                    Text("Layout")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Video Culling Orientation:")
                                .frame(width: 200, alignment: .leading)

                            Picker("", selection: $preferences.orientation) {
                                ForEach(UserPreferences.OrientationOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .accessibilityIdentifier("orientationPicker")
                            .frame(width: 250)
                            .help("Vertical: Videos displayed top-to-bottom in a scrollable list\nHorizontal: Videos displayed in a thumbnail strip with large preview above")
                        }

                        if preferences.orientation == .horizontal {
                            Text("Note: Horizontal mode shows a thumbnail strip at the bottom with a large preview above")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 200)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Advanced Preferences
struct AdvancedPreferencesView: View {
    @ObservedObject var preferences: UserPreferences
    @ObservedObject var lutManager: LUTManager
    @Binding var showingLUTManager: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section: LUT Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("LUT Settings")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Toggle("Apply Default LUTs to Preview", isOn: $preferences.applyDefaultLUTsToPreview)
                                .frame(width: 300, alignment: .leading)
                                .help("When enabled, automatically applies default LUTs to video previews based on camera metadata")
                        }

                        Divider()

                        HStack {
                            Text("LUT Manager:")
                                .frame(width: 200, alignment: .leading)

                            Button("Manage LUTs...") {
                                showingLUTManager = true
                            }
                            .help("Import, organize, and delete custom LUTs")

                            Text("\(lutManager.availableLUTs.count) LUTs available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Testing
                VStack(alignment: .leading, spacing: 12) {
                    Text("Testing")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Test Mode", isOn: $preferences.testMode)
                                .frame(width: 200, alignment: .leading)
                                .help("When enabled, videos are exported to a 'Culled' subfolder instead of the destination folder. No files are deleted or modified.")

                            if preferences.testMode {
                                Text("Videos will export to 'Culled' subfolder")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Reset
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Welcome Screen:")
                                .frame(width: 200, alignment: .leading)

                            Button("Show Welcome Screen Again") {
                                UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
                            }
                            .help("Reset the welcome screen to show on next app launch")
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Hotkey Preferences
struct HotkeyPreferencesView: View {
    @ObservedObject var preferences: UserPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Keyboard Visual Guide
                KeyboardVisualizationView()
                    .padding(.bottom, 8)

                Divider()

                // Section: Navigation Hotkeys
                VStack(alignment: .leading, spacing: 12) {
                    Text("Navigation")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Navigate Next:")
                                .frame(width: 200, alignment: .leading)

                            Text("Left Arrow")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)

                            Text("(Left Arrow in horizontal mode, Down Arrow in vertical mode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Navigate Previous:")
                                .frame(width: 200, alignment: .leading)

                            Text("Right Arrow")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)

                            Text("(Right Arrow in horizontal mode, Up Arrow in vertical mode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack(alignment: .top) {
                            Text("Frame Skimming:")
                                .frame(width: 200, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("Shift + Left Arrow")
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(6)

                                    Text("Shift + Right Arrow")
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(6)
                                }

                                Text("(Step backward/forward one frame at a time on the playhead)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Playback Hotkeys
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playback")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Play/Pause:")
                                .frame(width: 200, alignment: .leading)

                            Text("Space")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)

                            Text("(Spacebar)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section: Editing Hotkeys
                VStack(alignment: .leading, spacing: 12) {
                    Text("Editing")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Set In Point:")
                                .frame(width: 200, alignment: .leading)

                            TextField("", text: $preferences.hotkeySetInPoint)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .font(.system(.body, design: .monospaced))
                                .textCase(.uppercase)

                            Text("(Sets trim in-point at current playhead position)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Set Out Point:")
                                .frame(width: 200, alignment: .leading)

                            TextField("", text: $preferences.hotkeySetOutPoint)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .font(.system(.body, design: .monospaced))
                                .textCase(.uppercase)

                            Text("(Sets trim out-point at current playhead position)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Mark for Deletion:")
                                .frame(width: 200, alignment: .leading)

                            TextField("", text: $preferences.hotkeyToggleDeletion)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .font(.system(.body, design: .monospaced))
                                .textCase(.uppercase)

                            Text("(Toggles deletion flag for current video)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            Text("Reset Trim Points:")
                                .frame(width: 200, alignment: .leading)

                            TextField("", text: $preferences.hotkeyResetTrimPoints)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .font(.system(.body, design: .monospaced))
                                .textCase(.uppercase)

                            Text("(Resets trim points to full video duration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Info box
                VStack(alignment: .leading, spacing: 8) {
                    Label("Hotkey Information", systemImage: "info.circle")
                        .font(.headline)

                    Text("Hotkeys work when the app is focused and you're not typing in a text field. Default hotkeys (A, S, D, F) are optimized for standard hand positioning on the keyboard.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Tip: You can customize hotkeys by typing a single letter in the text fields above. Changes save automatically.")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Keyboard Visualization
struct KeyboardVisualizationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Keyboard Layout Guide")
                .font(.headline)

            Text("Position your hands for optimal workflow")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Keyboard visual
            HStack(spacing: 40) {
                // Left hand section
                VStack(spacing: 12) {
                    Text("Left Hand")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        // Shift key (pinky)
                        KeyCapView(label: "Shift", isHighlighted: false, width: 60)

                        Spacer()
                            .frame(width: 20)

                        // A, S, D, F keys (pinky, ring, middle, index)
                        KeyCapView(label: "A", isHighlighted: true, width: 36)
                        KeyCapView(label: "S", isHighlighted: true, width: 36)
                        KeyCapView(label: "D", isHighlighted: true, width: 36)
                        KeyCapView(label: "F", isHighlighted: true, width: 36)
                    }

                    // Spacebar (thumb)
                    KeyCapView(label: "Space", isHighlighted: true, width: 180)

                    // Hand indicator
                    HStack(spacing: 4) {
                        Text("👈")
                            .font(.title)
                        Text("Left hand controls trim points, deletion, and reset")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .frame(height: 120)

                // Right hand section
                VStack(spacing: 12) {
                    Text("Right Hand")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Arrow keys
                    VStack(spacing: 4) {
                        KeyCapView(label: "↑", isHighlighted: true, width: 36)
                        HStack(spacing: 4) {
                            KeyCapView(label: "←", isHighlighted: true, width: 36)
                            KeyCapView(label: "↓", isHighlighted: true, width: 36)
                            KeyCapView(label: "→", isHighlighted: true, width: 36)
                        }
                    }

                    Spacer()
                        .frame(height: 8)

                    // Shift + Arrow keys note
                    Text("Hold Shift + ← / →")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    Text("for frame-by-frame skimming")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()
                        .frame(height: 8)

                    // Hand indicator
                    HStack(spacing: 4) {
                        Text("👉")
                            .font(.title)
                        Text("Right hand navigates between clips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

// MARK: - Key Cap View
struct KeyCapView: View {
    let label: String
    var isHighlighted: Bool = false
    var width: CGFloat = 40

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(isHighlighted ? .white : .primary)
            .frame(width: width, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.blue : Color.gray.opacity(0.2))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHighlighted ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
    }
}
