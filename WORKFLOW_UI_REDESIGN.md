# Workflow UI Redesign

## Overview

Redesigned the workflow UI to simplify the user experience with visual process flow diagrams and smart workflow detection.

## Changes Made

### 1. Welcome Screen (WelcomeView.swift)

- **Single "GO!" Button**: Replaced "Start Import" and "Cull in Place" buttons with one smart "GO!" button
- **Smart Detection**: Automatically detects if destination folder is empty or same as source
- **Improved Warning**: Shows detailed warning popup when culling in place is detected
- **User Options**: Popup offers "Add Different Destination" or "Proceed with Culling in Place"

Key logic in `handleGoButton()`:
```swift
private func handleGoButton() {
    let isSameFolder = inputURL.path == outputURL.path
    let isOutputEmpty = !FileManager.default.fileExists(atPath: outputURL.path) ||
                       (try? FileManager.default.contentsOfDirectory(atPath: outputURL.path))?.isEmpty == true

    if isSameFolder || isOutputEmpty {
        showCullInPlaceWarning = true
    } else {
        viewModel.setImportMode()
        startWorkflow()
    }
}
```

### 2. Main Content View (ContentView.swift)

- **Removed**: Folder selection buttons and workflow mode picker from toolbar
- **Added**: Compact visual workflow diagram in toolbar
- **Simplified**: Cleaner, more intuitive interface

### 3. New Component: CompactWorkflowView.swift

A new reusable component that displays:

#### Visual Process Flow
- **Source Node**: Shows source folder with file count and space
- **Staging Node**: Conditional - only shows for external media
- **Output Node**: Shows destination folder
- **FCP Export Node**: Toggle for FCPXML export

#### File Statistics
Each node displays:
- `Files: X` - Total number of files
- `Space: X GB` - Total space occupied

#### Cleanup Buttons
After job completion:
- Source cleanup button (only shown after staging used)
- Staging cleanup button (moves files to trash)

#### Process Button
- Large "Process Import/Culling Job" button to the right
- Disabled when requirements not met
- Triggers the main processing workflow

### 4. Features

#### Real-time Statistics
- Asynchronous calculation of file counts and folder sizes
- Updates when folders change
- Security-scoped resource access for sandboxed app

#### Smart Cleanup
- Post-processing cleanup buttons
- Confirmation dialogs before deletion
- Moves files to trash (recoverable)

#### Interactive Nodes
- Clickable nodes to change folder selections
- Hover effects for better UX
- Completion indicators (checkmarks)
- Visual flow arrows showing data movement

## Technical Implementation

### File Statistics Calculation
```swift
private func calculateFolderStats(_ url: URL) async -> (count: Int, sizeGB: Double) {
    // Security-scoped access
    guard url.startAccessingSecurityScopedResource() else { return (0, 0.0) }
    defer { url.stopAccessingSecurityScopedResource() }

    // Enumerate and calculate
    let fileManager = FileManager.default
    if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
        // Count files and sum sizes
    }
}
```

### Cleanup Safety
```swift
private func cleanupSourceFiles() {
    let alert = NSAlert()
    alert.messageText = "Delete Source Files?"
    alert.informativeText = "This will move all files from the source folder to the trash..."
    alert.alertStyle = .warning

    if alert.runModal() == .alertSecondButtonReturn {
        // Move to trash
    }
}
```

## User Experience Flow

1. **Initial Setup (Welcome Screen)**:
   - User selects source folder → scanning begins automatically in background
   - User selects output folder (optional staging if external media)
   - User clicks "GO!" button

2. **Smart Detection**:
   - If output is same/empty → Warning shown
   - User chooses: add different destination OR proceed with culling
   - Otherwise → Proceeds to import mode

3. **Main Workflow View**:
   - Visual nodes show selected folders
   - File counts and space usage visible
   - Click nodes to change selections
   - Toggle FCP export if needed
   - Big "Process Import/Culling Job" button when ready

4. **After Processing**:
   - Cleanup buttons appear for source/staging
   - User can clean up the data chain easily

## Benefits

- **Simpler**: One button instead of two modes
- **Clearer**: Visual representation of data flow
- **Safer**: Smart detection prevents accidental data loss
- **More Informative**: Real-time statistics for each step
- **Easier Cleanup**: Post-processing cleanup buttons

## Manual Xcode Steps Required

The file `Views/CompactWorkflowView.swift` needs to be manually added to the Xcode project:

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Right-click on the `Views` folder group
3. Select "Add Files to VideoCullingApp"
4. Navigate to and select `Views/CompactWorkflowView.swift`
5. Ensure "Copy items if needed" is unchecked
6. Ensure "VideoCullingApp" target is checked
7. Click "Add"

Alternatively, the Python script in this commit should have added it automatically to the project.pbxproj file.
