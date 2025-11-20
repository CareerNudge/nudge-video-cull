# Unimplemented Features and Requirements

This document tracks all planned features and requirements that have not yet been implemented in the VideoCullingApp.

## High Priority Features

### 1. Horizontal Gallery Mode
**Status:** Preference exists, UI not implemented
**Location:** PreferencesView.swift lines 309-328
**Description:** Users can select "Horizontal" orientation in preferences, but the gallery view doesn't change layout.

**Requirements:**
- Implement `HorizontalGalleryView` as an alternative to the current vertical scrolling list
- Layout should show:
  - Large preview video player at the top
  - Thumbnail filmstrip/carousel at the bottom
  - Selected video in filmstrip should be highlighted
  - Clicking thumbnails should switch the large preview
- Integrate with existing preference: `UserPreferences.shared.orientation`
- Update `GalleryView.swift` to conditionally render based on orientation preference

**Design Notes:**
- Horizontal mode should maintain all functionality of vertical mode
- Editable fields (re-naming, LUT, rating, keywords) should appear to the side or below the preview
- Thumbnails should show key metadata overlays (duration, resolution, flagged status)

---

### 2. Workflow Mode Selector UI
**Status:** Backend logic exists, no UI to select mode
**Location:** ContentViewModel.swift lines 43-49
**Description:** The app has two workflow modes defined but no way for users to choose between them.

**Workflow Modes:**
1. **Import Mode**: Requires both input and output folders
   - Copies/processes videos from input to output
   - Allows trimming, LUT baking, renaming
   - Original files remain untouched

2. **Cull In Place**: Only requires input folder
   - Deletes unwanted files from input folder
   - No copying or moving
   - Destructive operation (should warn user)

**Requirements:**
- Add workflow mode selector to UI (radio buttons or segmented control)
- Location suggestions:
  - In the top toolbar between folder selectors
  - In the Preferences → General tab
  - As a popup on first use
- Update button text based on mode:
  - Import Mode: "Process and Import Videos"
  - Cull In Place: "Delete Flagged Files"
- Show clear warnings for "Cull In Place" mode
- Remember last selected mode in UserDefaults

---

### 3. Processing Cancellation
**Status:** TODO comment exists, not implemented
**Location:** ProcessingProgressView.swift line 132
**Description:** Users cannot cancel processing once it starts.

**Requirements:**
- Add "Cancel" button to ProcessingProgressView
- Implement cancellation logic in ContentViewModel
- Handle graceful shutdown of:
  - File scanning
  - Video processing
  - FFmpeg operations
  - File copying
- Clean up partial files on cancellation
- Restore app state to pre-processing state
- Show confirmation dialog: "Are you sure you want to cancel? Partial progress will be lost."

---

## Medium Priority Features

### 4. Fullscreen Player LUT Application
**Status:** Partial implementation
**Location:** FullscreenPlayerView.swift
**Description:** The fullscreen player doesn't apply LUT filters like the inline player does.

**Requirements:**
- Apply same LUT video composition to fullscreen player
- Ensure LUT updates when changed during fullscreen playback
- Maintain performance in fullscreen mode

---

### 5. External Media Performance Optimization
**Status:** Basic implementation complete, room for improvement
**Location:** ContentViewModel.swift (staging functions)
**Description:** Staging is now implemented with rsync, but could be further optimized.

**Potential Improvements:**
- Show estimated time remaining during staging
- Allow selective staging (only stage videos user wants to preview)
- Cache staging decisions per external volume
- Automatically clean up staging folder when done
- Support for multiple external drives simultaneously

---

### 6. Advanced Trimming Features
**Status:** Basic trim slider exists
**Location:** TrimRangeSlider in PlayerView.swift
**Description:** Current trimming is functional but could be enhanced.

**Potential Enhancements:**
- Frame-accurate trimming (show frame number)
- Jump to trim points with keyboard shortcuts
- Visual markers on waveform showing trim range
- "Trim to selection" based on waveform selection
- Precision mode with millisecond input
- Saved trim presets (e.g., "Remove first 2 seconds")

---

### 7. Batch Operations
**Status:** Not implemented
**Description:** Users cannot apply actions to multiple videos at once.

**Requirements:**
- Multi-select videos (Cmd+Click, Shift+Click)
- Batch operations:
  - Apply same LUT to selection
  - Apply same naming convention to selection
  - Flag/unflag selection for deletion
  - Set same rating for selection
  - Copy keywords to selection
- "Select All" / "Select None" buttons
- "Select Similar" (same resolution, codec, camera, etc.)

---

### 8. Search and Filtering
**Status:** Sort order exists, no filtering
**Location:** ContentView.swift has sort picker
**Description:** Users can sort but cannot filter the video list.

**Requirements:**
- Filter by:
  - Flagged for deletion (yes/no)
  - Rating (1-5 stars, unrated)
  - LUT applied (specific LUT, none, any)
  - Resolution (4K, HD, SD, etc.)
  - Duration (less than X seconds, greater than Y)
  - Codec (ProRes, H.264, etc.)
  - Has XML sidecar (yes/no)
  - Camera metadata (specific gamma/colorSpace)
- Search by filename
- Combine multiple filters (AND logic)
- Save filter presets
- Show filter count: "Showing 15 of 120 videos"

---

## Low Priority / Nice-to-Have Features

### 9. Export Presets
**Status:** Not implemented
**Description:** Users cannot save processing settings as reusable presets.

**Requirements:**
- Save preset including:
  - Naming convention
  - Default LUT mappings
  - Output format settings
  - Trim defaults
- Load preset by name
- Share presets between users (export/import)
- Built-in presets for common workflows

---

### 10. Keyboard Shortcuts
**Status:** Minimal shortcuts implemented
**Description:** More keyboard shortcuts would improve efficiency.

**Suggested Shortcuts:**
- `Space`: Play/Pause current video
- `→`: Next video
- `←`: Previous video
- `Delete`: Flag/unflag for deletion
- `1-5`: Set rating
- `I`: Set in point (trim start)
- `O`: Set out point (trim end)
- `Cmd+A`: Select all
- `Cmd+F`: Focus search
- `Cmd+L`: Open LUT picker for current video

---

### 11. Video Comparison View
**Status:** Not implemented
**Description:** Allow side-by-side comparison of videos.

**Requirements:**
- Select 2-4 videos for comparison
- Show synchronized playback
- Compare with/without LUT
- Useful for:
  - Choosing between similar shots
  - Verifying LUT application
  - Checking quality differences

---

### 12. Export Queue and Background Processing
**Status:** Processing blocks UI
**Description:** Large processing jobs block the UI.

**Requirements:**
- Queue multiple processing jobs
- Background processing without blocking UI
- Continue processing even if user switches folders
- Show progress notification when done
- Allow working on new folder while previous job processes

---

### 13. Undo/Redo System
**Status:** Not implemented
**Description:** No way to undo changes.

**Requirements:**
- Undo/redo for:
  - LUT selection
  - Trim points
  - Rating changes
  - Flag for deletion
  - Naming changes
  - Keyword edits
- Cmd+Z / Cmd+Shift+Z shortcuts
- Undo history panel

---

### 14. Project Save/Load
**Status:** Folder state is restored, but not full project
**Description:** Users cannot save their work as a project file.

**Requirements:**
- Save project file including:
  - All edits (trims, LUTs, ratings, keywords, names)
  - Folder locations
  - Workflow mode
  - Processing settings
- Load project to continue editing
- Recent projects list
- Auto-save every N minutes

---

### 15. Cloud Integration
**Status:** Not implemented
**Description:** No cloud storage integration.

**Potential Features:**
- Upload processed videos to:
  - iCloud Drive
  - Dropbox
  - Google Drive
  - Frame.io
- Sync projects across devices
- Share projects with collaborators

---

### 16. Analytics and Reporting
**Status:** Not implemented
**Description:** No visibility into processing history.

**Potential Features:**
- Report showing:
  - Total videos processed
  - Total footage duration
  - Average processing time
  - Space saved by trimming
  - Most-used LUTs
  - Files deleted vs. imported
- Export reports as CSV/PDF

---

## Technical Debt and Code Quality

### 17. Error Handling Improvements
**Current State:** Basic error handling exists
**Improvements Needed:**
- More descriptive error messages
- Error recovery strategies
- Retry mechanisms for transient failures
- Better logging for debugging

---

### 18. Unit Tests
**Status:** No tests exist
**Description:** No automated testing.

**Requirements:**
- Unit tests for:
  - FileScannerService
  - LUT parsing and application
  - Naming convention logic
  - Trim calculations
  - XML metadata parsing
- Integration tests for:
  - Full processing pipeline
  - File operations
  - Core Data operations

---

### 19. Performance Profiling
**Status:** Not done systematically
**Description:** App performance not profiled for large folders.

**Areas to Profile:**
- Thumbnail generation for 500+ videos
- LUT application overhead
- Core Data query performance
- Memory usage during processing
- Scrolling performance in gallery view

---

### 20. Accessibility
**Status:** Minimal support
**Description:** No VoiceOver or accessibility features.

**Requirements:**
- VoiceOver labels for all UI elements
- Keyboard navigation for entire UI
- High contrast mode support
- Screen reader announcements for status changes
- Accessibility inspector compliance

---

## Documentation Needed

### 21. User Guide
**Status:** Not created
**Description:** No user-facing documentation.

**Should Include:**
- Getting started tutorial
- Workflow examples
- Keyboard shortcuts reference
- LUT management guide
- Troubleshooting common issues
- Video format compatibility

---

### 22. Developer Documentation
**Status:** Minimal comments
**Description:** Code lacks comprehensive documentation.

**Should Include:**
- Architecture overview
- Core Data schema documentation
- LUT file format specifications
- FFmpeg command reference
- Build and deployment guide
- Contributing guidelines

---

## Notes

**Last Updated:** 2025-01-16
**Priority Criteria:**
- **High Priority:** Core functionality or user-requested features
- **Medium Priority:** Quality of life improvements
- **Low Priority:** Nice-to-have features for future consideration

**Status Definitions:**
- **Not Implemented:** Feature does not exist
- **Partial Implementation:** Feature exists but incomplete
- **TODO Comment:** Marked in code but not implemented
- **Preference Exists:** UI setting exists but no implementation
