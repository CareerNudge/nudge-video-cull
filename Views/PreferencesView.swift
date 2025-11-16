//
//  PreferencesView.swift
//  VideoCullingApp
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var id: String { self.rawValue }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .system:
            return nil
        }
    }
}

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    init() {
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
    }

    func applyAppearance() {
        NSApp.appearance = appearanceMode.nsAppearance
    }
}

struct PreferencesView: View {
    @ObservedObject var preferencesManager = PreferencesManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section(header: Text("Appearance").font(.headline)) {
                    Picker("Theme:", selection: $preferencesManager.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            HStack {
                                switch mode {
                                case .light:
                                    Image(systemName: "sun.max.fill")
                                case .dark:
                                    Image(systemName: "moon.fill")
                                case .system:
                                    Image(systemName: "circle.lefthalf.filled")
                                }
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Choose your preferred color theme for the application.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .formStyle(.grouped)
            .padding()

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
    }
}
