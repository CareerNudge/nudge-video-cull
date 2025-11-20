# Xcode Manual Steps for Preferences and Loading Screen Features

## Overview
This document outlines the manual steps required in Xcode to integrate:
1. Loading Progress View with file analysis
2. Preferences Window with all settings
3. Horizontal Gallery Mode (to be implemented)
4. Play-Through Functionality (to be implemented)

## Files Created

### 1. LoadingProgressView.swift
**Location:** `Views/LoadingProgressView.swift`
**Purpose:** Popup window showing scan progress with detailed file analysis status

### 2. PreferencesView.swift
**Location:** `Views/PreferencesView.swift`
**Purpose:** Tabbed preferences window with all user settings

## Xcode Steps

### Step 1: Add New Files to Xcode Project

1. In Xcode, right-click on the `Views` folder in the Project Navigator
2. Select "Add Files to VideoCullingApp..."
3. Navigate to and select:
   - `Views/LoadingProgressView.swift`
   - `Views/PreferencesView.swift`
4. Ensure "Copy items if needed" is UNCHECKED
5. Ensure "Create groups" is selected
6. Ensure "VideoCullingApp" target is checked
7. Click "Add"

### Step 2: Verify File Membership

1. Select each new file in Project Navigator
2. In File Inspector (right panel), verify:
   - Target Membership: "VideoCullingApp" is checked

### Step 3: Build and Fix Any Errors

Run the build (Cmd+B) and address any compilation errors that may appear.

## Integration Points

### ContentView Integration (To Be Implemented)

The following changes need to be made to `ContentView.swift`:

1. **Add state for loading progress:**
   ```swift
   @State private var showLoadingProgress = false
   ```

2. **Show loading progress instead of inline loading:**
   ```swift
   .sheet(isPresented: $showLoadingProgress) {
       LoadingProgressView(viewModel: viewModel, isPresented: $showLoadingProgress)
   }
   ```

3. **Add preferences menu item:**
   ```swift
   .commands {
       CommandGroup(replacing: .appSettings) {
           Button("Preferences...") {
               showPreferences = true
           }
           .keyboardShortcut(",", modifiers: .command)
       }
   }
   ```

4. **Add preferences window:**
   ```swift
   .sheet(isPresented: $showPreferences) {
       PreferencesView()
   }
   ```

### GalleryView Integration (To Be Implemented)

1. **Remove Test Mode toggle** - This will move to Preferences
2. **Remove LUT Manager button** - This will move to Preferences  
3. **Remove Naming Convention picker** - This will move to Preferences
4. **Add Preferences button** in the top controls area

## Preferences Features

### General Tab
- **Default Source Folder:** "Last Used" or "Choose a Default Path"
- **Default Destination Folder:** "Last Used" or "Choose a Default Path"
- **Video Play-Through:** Enable/Disable automatic advancement
- **Default Re-Naming:** Naming convention picker (moved from main screen)

### Appearance Tab
- **Theme:** Dark, Light, or Follow Computer Settings
- **Video Culling Orientation:** Vertical or Horizontal

### Advanced Tab
- **Apply Default LUTs to Preview:** Enable/Disable
- **LUT Manager:** Button to open LUT management window
- **Test Mode:** Enable/Disable (moved from main screen)

## Loading Progress Features

### What's Shown
- Current operation status from FileScannerService
- Progress bar (current file / total files)
- Current file being analyzed
- List of analysis steps being performed:
  - Video codec, resolution, frame rate
  - Audio channels and sample rate
  - Camera metadata (gamma, color space)
  - Automatic LUT mapping
  - Thumbnail generation

### User Actions
- Select destination folder while loading
- Close button (only when loading completes)

## Tooltips Implemented

All preference options have `.help()` modifiers showing:
- What the setting does
- What each option means
- Expected behavior when enabled/disabled

## Next Steps

1. **Integrate LoadingProgressView** into ContentViewModel.scan()
2. **Integrate PreferencesView** with menu command
3. **Sync preferences** with ContentViewModel (test mode, naming convention)
4. **Implement HorizontalGalleryView** for horizontal orientation
5. **Implement Play-Through** logic in PlayerView
6. **Apply theme** based on user preference

## Testing Checklist

- [ ] Loading progress appears when selecting source folder
- [ ] Progress bar updates as files are scanned  
- [ ] Current file name displays correctly
- [ ] Destination folder can be changed during loading
- [ ] Preferences window opens from menu (Cmd+,)
- [ ] All preference tabs load correctly
- [ ] Preference changes persist across app restarts
- [ ] Tooltips appear on hover for all settings
- [ ] Test mode moved from main screen to preferences
- [ ] LUT Manager opens from preferences
- [ ] Default naming convention works from preferences
