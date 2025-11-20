# Hotkey System - Manual Integration Steps

**Date**: 2025-11-19
**Status**: 🔄 REQUIRES MANUAL XCODE STEPS
**Priority**: HIGH - Part of Fix #3

---

## Files Created

1. **Services/HotkeyManager.swift** - NEW (needs to be added to Xcode project)
2. **Views/PreferencesView.swift** - UPDATED (added hotkey preferences UI)

---

## Manual Xcode Steps Required

### 1. Add HotkeyManager.swift to Xcode Project

**IMPORTANT**: The file `Services/HotkeyManager.swift` exists on disk but must be manually added to the Xcode project.

Steps:
1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Right-click the **Services** folder in the Project Navigator
3. Select **Add Files to "VideoCullingApp"...**
4. Navigate to `Services/HotkeyManager.swift`
5. Ensure "Copy items if needed" is **UNCHECKED** (file already in correct location)
6. Ensure "Add to targets: VideoCullingApp" is **CHECKED**
7. Click **Add**

### 2. Verify PreferencesView Updates

The following changes were made to `PreferencesView.swift`:
- Added `hotkeys` case to `PreferenceSection` enum
- Added hotkey storage properties to `UserPreferences` class
- Added `HotkeyPreferencesView` struct with UI
- Hotkeys are now visible in Preferences → Hotkeys tab

---

## Hotkey Implementation Summary

### Hotkeys Configured (Default Values)
- **Navigate Next**: Right Arrow (code: 124)
- **Navigate Previous**: Left Arrow (code: 123)
- **Play/Pause**: Space (code: 49)
- **Set In Point**: Z
- **Set Out Point**: X
- **Mark for Deletion**: C

### Architecture
- **HotkeyManager**: Singleton NSEvent monitor for keyboard events
- **UserPreferences**: Stores hotkey configurations in UserDefaults
- **PreferencesView**: UI for viewing (and eventually editing) hotkeys

### Integration Status
- ✅ HotkeyManager service created
- ✅ UserPreferences storage added
- ✅ Preferences UI created
- ⏸️ Action binding (DEFERRED - requires GalleryView and PlayerView integration)

---

## Remaining Integration Work (DEFERRED)

The following integration steps are **documented but not yet implemented** due to complexity:

### A. Video Navigation Actions (GalleryView)
```swift
// In GalleryView or ContentViewModel
@StateObject private var hotkeyManager = HotkeyManager.shared

.onAppear {
    hotkeyManager.onNavigateNext = {
        // Navigate to next video in sortedAssets
    }
    hotkeyManager.onNavigatePrevious = {
        // Navigate to previous video in sortedAssets
    }
}
```

### B. Playback Actions (PlayerView)
```swift
// In PlayerView
hotkeyManager.onTogglePlayPause = {
    if isPlaying {
        player.pause()
    } else {
        player.play()
    }
}
```

### C. Trim Actions (PlayerView)
```swift
hotkeyManager.onSetInPoint = {
    if let player = player {
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let normalizedTime = currentTime / videoDuration
        asset.trimStartTime = normalizedTime
    }
}

hotkeyManager.onSetOutPoint = {
    if let player = player {
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let normalizedTime = currentTime / videoDuration
        asset.trimEndTime = normalizedTime
    }
}
```

### D. Deletion Toggle (VideoAssetRowView)
```swift
hotkeyManager.onToggleDeletion = {
    asset.isFlaggedForDeletion.toggle()
}
```

---

## Testing Requirements

### Manual Testing
- [ ] All hotkeys respond when app is focused
- [ ] Hotkeys don't interfere with text field input
- [ ] Navigation works in both horizontal and vertical modes
- [ ] Play/pause toggles correctly
- [ ] Trim markers update at playhead position
- [ ] Deletion flag toggles visually

### Automated Testing
- [ ] Test hotkey configuration saves/loads
- [ ] Test hotkey preferences UI displays correctly
- [ ] Test HotkeyManager event monitoring (if possible)

---

## Build Status

**Next Step**: Build project to verify compilation with HotkeyManager added to Xcode.

```bash
xcodebuild -project VideoCullingApp.xcodeproj \
           -scheme VideoCullingApp \
           -configuration Debug \
           build
```

---

## Notes

- Hotkey customization UI will be added in a future update
- Current implementation uses fixed key codes
- Action binding deferred to avoid complexity and maintain focus on core fixes
- HotkeyManager framework is complete and ready for integration when needed
