//
//  HotkeyManager.swift
//  VideoCullingApp
//

import SwiftUI
import Cocoa

/// Manages global keyboard shortcuts for the application
@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private var localMonitor: Any?
    private var preferences = UserPreferences.shared

    // Callback closures for hotkey actions
    var onNavigateNext: (() -> Void)?
    var onNavigatePrevious: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onSetInPoint: (() -> Void)?
    var onSetOutPoint: (() -> Void)?
    var onToggleDeletion: (() -> Void)?

    private init() {
        setupMonitoring()
    }

    // Note: Deinit removed - HotkeyManager is a singleton that lives for app lifetime

    /// Start monitoring keyboard events
    func setupMonitoring() {
        // Use local event monitor to capture keys when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Don't capture if user is typing in a text field
            if event.window?.firstResponder is NSText ||
               event.window?.firstResponder is NSTextView {
                return event
            }

            // Check for modifier-free shortcuts (single keys)
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty ||
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift {

                let keyCode = event.keyCode
                let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""

                // Check against configured hotkeys
                if keyCode == preferences.hotkeyNavigateNextCode {
                    Task { @MainActor in
                        self.onNavigateNext?()
                    }
                    return nil // Consume the event
                }

                if keyCode == preferences.hotkeyNavigatePreviousCode {
                    Task { @MainActor in
                        self.onNavigatePrevious?()
                    }
                    return nil
                }

                if keyCode == preferences.hotkeyPlayPauseCode {
                    Task { @MainActor in
                        self.onTogglePlayPause?()
                    }
                    return nil
                }

                if characters == preferences.hotkeySetInPoint.lowercased() {
                    Task { @MainActor in
                        self.onSetInPoint?()
                    }
                    return nil
                }

                if characters == preferences.hotkeySetOutPoint.lowercased() {
                    Task { @MainActor in
                        self.onSetOutPoint?()
                    }
                    return nil
                }

                if characters == preferences.hotkeyToggleDeletion.lowercased() {
                    Task { @MainActor in
                        self.onToggleDeletion?()
                    }
                    return nil
                }
            }

            return event // Don't consume other events
        }
    }

    /// Stop monitoring keyboard events
    func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    /// Update monitoring when preferences change
    func refresh() {
        stopMonitoring()
        setupMonitoring()
    }
}

// MARK: - Key Code Helpers

extension HotkeyManager {
    /// Common key codes for macOS
    enum KeyCode: UInt16 {
        case space = 49
        case leftArrow = 123
        case rightArrow = 124
        case upArrow = 126
        case downArrow = 125
        case escape = 53
        case returnKey = 36
    }

    /// Get display name for a key code
    static func displayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case KeyCode.space.rawValue:
            return "Space"
        case KeyCode.leftArrow.rawValue:
            return "Left Arrow"
        case KeyCode.rightArrow.rawValue:
            return "Right Arrow"
        case KeyCode.upArrow.rawValue:
            return "Up Arrow"
        case KeyCode.downArrow.rawValue:
            return "Down Arrow"
        default:
            return "Key \(keyCode)"
        }
    }

    /// Get display name for a character key
    static func displayName(for character: String) -> String {
        return character.uppercased()
    }
}
