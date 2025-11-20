# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ CRITICAL: Git Workflow Rules

**DO NOT commit or push changes unless explicitly instructed by the user.**

- Make code changes and fixes as requested
- Build and test to verify changes work
- Wait for the user to explicitly ask to commit before running any git commands
- When the user does ask to commit, follow the standard commit process with proper messages

## Project Overview

**Nudge Video Cull** is a professional macOS video culling application for efficiently reviewing, trimming, and processing video files with LUT support. Built with SwiftUI, AVFoundation, and Core Data, it's designed to be 100% App Store compliant with no FFmpeg or GPL/LGPL dependencies.

## Build and Development Commands

### Building the Project

```bash
# Clean build
# In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

# Build release version
xcodebuild -project VideoCullingApp.xcodeproj \
           -scheme VideoCullingApp \
           -configuration Release \
           -derivedDataPath ./build

# Archive for distribution
# In Xcode: Product → Archive
```

### Required Manual Xcode Setup

Before building, certain files must be manually added to the Xcode project:

1. **Services folder** - Add these files if missing:
   - `Services/SonyXMLParser.swift`
   - `Services/LUTAutoMapper.swift`
   - `Services/FCPXMLExporter.swift`

2. **Views folder** - Add these files if missing:
   - `Views/WelcomeView.swift`
   - `Views/ProcessingProgressView.swift`
   - `Views/RowSubviews/EnrichedMetadataView.swift`

3. **DefaultLuts folder** - Must be added as a **folder reference** (blue folder, not yellow group):
   - Right-click project root → Add Files → DefaultLuts
   - Choose "Create folder references"
   - This preserves the folder structure in the app bundle

See `XCODE_MANUAL_STEPS.md` for complete instructions.

## Architecture

### MVVM Pattern with SwiftUI

```
VideoCullingApp/
├── Views/              # SwiftUI views (UI layer)
├── ViewModels/         # State management (@ObservableObject)
├── Services/           # Business logic and processing
├── Models/             # Core Data model extensions
├── Persistence/        # Core Data stack
└── Assets.xcassets/    # Images and resources
```

### Core Services

**FileScannerService** (`Services/FileScannerService.swift`)
- Scans folders for video files recursively
- Extracts metadata using AVFoundation
- Parses Sony XML sidecar files for camera metadata
- Populates Core Data with ManagedVideoAsset entities
- Auto-applies LUT mappings based on camera gamma/colorSpace

**ProcessingService** (`Services/ProcessingService.swift`)
- 100% native AVFoundation video processing
- Smart export preset selection:
  - **Passthrough**: Lossless trimming without re-encoding
  - **HighestQuality**: Re-encodes when baking LUTs
- Handles trimming, LUT baking, renaming, and deletion
- Supports both "import to output folder" and "process in-place" workflows

**LUTManager** (`Services/LUTManager.swift`)
- Manages .cube LUT files (user-imported + bundled defaults)
- Loads default LUTs from `DefaultLuts/` folder in bundle
- Learning system: remembers user LUT preferences per camera gamma/colorSpace
- Stores user LUT mappings in `userLUTMappings.json`
- Provides CIColorCube filters for video composition

**LUTParser** (`Services/LUTParser.swift`)
- Native .cube LUT file parser (no FFmpeg)
- Creates CIColorCube filters for CoreImage
- App Store compliant

**LUTAutoMapper** (`Services/LUTAutoMapper.swift`)
- Auto-maps LUTs based on camera metadata (gamma, colorSpace)
- Built-in mappings for common Sony profiles (S-Log3, S-Gamut3.Cine, etc.)
- Falls back to user-learned preferences

**SonyXMLParser** (`Services/SonyXMLParser.swift`)
- Parses Sony XML sidecar files (`.xml` next to video files)
- Extracts: gamma, colorSpace, camera model, lens model, timecode, FPS
- Enriches video metadata with professional camera settings

**FCPXMLExporter** (`Services/FCPXMLExporter.swift`)
- Exports processed video list as FCPXML for Final Cut Pro
- Preserves trim points, metadata, and organization

### Core Data Model

**Entity: ManagedVideoAsset** (defined in `VideoCullingApp.xcdatamodeld`)

Key attributes:
- `filePath`, `fileName`, `newFileName` - File management
- `trimStartTime`, `trimEndTime` - Trim points (0.0 to 1.0 normalized)
- `selectedLUTId`, `bakeInLUT` - LUT application
- `isFlaggedForDeletion` - Mark for deletion
- `userRating` (0-5), `keywords` - User metadata
- `videoWidth`, `videoHeight`, `duration`, `fileSize`, `frameRate` - Technical metadata
- `captureGamma`, `captureColorPrimaries` - Camera metadata
- `hasXMLSidecar` - Indicates enriched metadata from Sony XML
- `cameraManufacturer`, `cameraModel`, `lensModel` - Camera info
- `timecode`, `captureFps` - Professional metadata

**Uniqueness constraint**: `filePath` (prevents duplicate entries)

**Access pattern**:
```swift
let context = persistenceController.container.viewContext
let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
```

### State Management

**ContentViewModel** (`ViewModels/ContentViewModel.swift`)
- Main application state (`@MainActor class`)
- Manages folder selection with security-scoped bookmarks
- Coordinates scanning, processing, and FCPXML export
- Workflow modes: `.importMode` (copy to output) vs `.cullInPlace` (delete in-place)
- External media detection and staging (rsync-based)
- Preference bindings via `UserPreferences.shared`

**UserPreferences** (UserDefaults-backed singleton)
- Test mode, naming conventions, appearance settings
- Source/destination folder defaults
- LUT auto-apply preferences
- Accessed via `UserPreferences.shared.testMode`, etc.

### Video Processing Pipeline

1. **Scan**: `FileScannerService.scan()` → Populate Core Data
2. **Edit**: User modifies trim points, selects LUTs, flags for deletion
3. **Process**: `ProcessingService.processChanges()`
   - Deletion phase (if in-place mode)
   - Processing phase: trim + LUT baking
   - Renaming phase (if in-place mode)
4. **Export**: Optional FCPXML export via `FCPXMLExporter`

### LUT Application Flow

**Preview** (real-time in UI):
```swift
// PlayerView.swift applies LUT to CIImage for preview
let filteredImage = LUTManager.shared.applyLUT(selectedLUT, to: ciImage)
```

**Baking** (during export):
```swift
// ProcessingService creates AVVideoComposition with LUT filter
let composition = createLUTComposition(for: avAsset, lutData: lutData)
exportSession.videoComposition = composition
```

### External Media Staging

When scanning folders on external drives (USB, SD cards), the app detects this and offers to stage files locally using `rsync` for optimal performance:

```swift
// ContentViewModel.swift
func isOnExternalMedia(_ url: URL) -> Bool
func stageFromExternalMedia(sourceURL: URL, destinationURL: URL?)
```

Staging copies videos + Sony XML sidecars to local storage before processing.

## Important Implementation Details

### Core Data Migrations

The app clears all video assets on launch (`VideoCullingApp.swift`):
```swift
func clearAllVideoAssets()
```

This ensures a fresh state each time. The "project" is the current folder + user edits in memory/Core Data.

### Security-Scoped Bookmarks

macOS sandboxing requires persistent access to user-selected folders:
```swift
// Save bookmark when user selects folder
private func saveSecurityScopedBookmark(url: URL, key: String)

// Restore on app launch
private func restoreSecurityScopedBookmark(key: String) -> URL?
```

Always call `url.startAccessingSecurityScopedResource()` when restoring.

### Trim Time Normalization

Trim points are stored as normalized values (0.0 to 1.0):
- `0.0` = start of video
- `1.0` = end of video
- Actual time = `normalizedTime * videoDuration`

This allows trim points to work correctly even if video duration changes.

### LUT File Locations

- **Default LUTs**: `Bundle.main.resourcePath/DefaultLuts/` (read-only)
- **User LUTs**: `~/Library/Application Support/VideoCullingApp/LUTs/`
- **LUT list**: `~/Library/Application Support/VideoCullingApp/luts.json`
- **User mappings**: `~/Library/Application Support/VideoCullingApp/userLUTMappings.json`

### Test Mode vs Normal Mode

**Test Mode** (safe preview):
- Only processes videos with actual changes (trim/LUT)
- Outputs to `Culled` subfolder
- Original files untouched

**Normal Mode** (production):
- Processes ALL files
- Can delete flagged files
- Can rename/move files
- Can process in-place or to output folder

Toggle in preferences: `UserPreferences.shared.testMode`

### Naming Conventions

Applied via `ContentViewModel.applyNamingConvention()`:
- `.none`: No renaming
- `.datePrefix`: `YYYYMMDD-[Original Name]`
- `.dateSuffix`: `[Original Name]-YYYYMMDD`
- `.dateTimePrefix`: `YYYYMMDD-HHMMSS-[Original Name]`

Uses earliest of creation date or modification date.

## Common Patterns

### Adding a new Service

1. Create file in `Services/` folder
2. Add to Xcode project (right-click Services → Add Files)
3. Inject dependencies via init (typically Core Data context)
4. Use `@MainActor` for UI-updating methods
5. Use `@Sendable` closures for progress callbacks

### Adding Core Data Attributes

1. Open `VideoCullingApp.xcdatamodeld`
2. Add attribute to `ManagedVideoAsset` entity
3. Xcode auto-generates the class (don't manually edit)
4. Add convenience extensions in `Models/ManagedVideoAsset+Extensions.swift`
5. Update `FileScannerService` or `ProcessingService` to populate/use the field

### Adding a new View

1. Create file in `Views/` folder
2. Add to Xcode project
3. Follow SwiftUI conventions
4. Access Core Data via `@FetchRequest` or pass entities as parameters
5. For preferences, use `@AppStorage` or `UserPreferences.shared`

## File References

Key files to understand the system:

- Architecture: `VideoCullingApp.swift` (entry point), `ContentViewModel.swift` (main state)
- Video processing: `ProcessingService.swift`, `LUTManager.swift`, `LUTParser.swift`
- Metadata: `FileScannerService.swift`, `SonyXMLParser.swift`, `LUTAutoMapper.swift`
- UI: `ContentView.swift`, `GalleryView.swift`, `VideoAssetRowView.swift`, `PlayerView.swift`
- Data: `Persistence.swift`, `VideoCullingApp.xcdatamodeld`, `ManagedVideoAsset+Extensions.swift`

## Documentation Files

- `README.md` - Project overview and features
- `BUILD_AND_EXPORT.md` - Complete build and distribution guide
- `XCODE_MANUAL_STEPS.md` - Required manual file additions
- `COMPLETED_FEATURES.md` - Implemented features checklist
- `UNIMPLEMENTED_FEATURES.md` - Planned features and technical debt
- `FCPXML_SETUP_INSTRUCTIONS.md` - FCPXML export feature guide
- `LUT_AUTO_MAPPING_FEATURE.md` - LUT auto-mapping system documentation
- `SONY_XML_FEATURE_SUMMARY.md` - Sony XML metadata parsing guide
- `CORE_DATA_MIGRATION_VIDEO_DIMENSIONS.md` - Core Data migration notes

## Known Limitations

1. **No FFmpeg**: App uses only AVFoundation (App Store requirement)
2. **No project files**: Edits are stored in Core Data, cleared on launch
3. **Single-threaded processing**: Videos processed sequentially (not parallel)
4. **No undo/redo**: Changes are immediate (see UNIMPLEMENTED_FEATURES.md)
5. **Manual Xcode steps**: Some files must be added manually to Xcode project

## App Store Compliance Checklist

- ✅ No FFmpeg or GPL/LGPL dependencies
- ✅ Native AVFoundation video processing
- ✅ CoreImage LUT baking with CIColorCube
- ⚠️ App Sandboxing (must enable manually)
- ⚠️ Privacy descriptions (must add to Info.plist)
- ⚠️ Code signing and notarization (for distribution)

See `BUILD_AND_EXPORT.md` for full submission checklist.
