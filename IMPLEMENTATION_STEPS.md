# Critical Fixes Implementation Steps

**Date**: 2025-11-19
**Project**: Nudge Video Cull - macOS Video Culling Application
**Priority**: CRITICAL - Core functionality broken
**Status**: Ready for Implementation

---

## Executive Summary

This document provides detailed implementation steps for 6 critical fixes to the video culling application. The fixes are organized by priority and dependency relationships to ensure efficient implementation without conflicts.

**Total Estimated Time**: 8-10 hours (including testing)

---

## Table of Contents

1. [Fix #4: Play Button Erratic Behavior (CRITICAL)](#fix-4-play-button-erratic-behavior)
2. [Fix #5: LUT Not Applying During Playback (CRITICAL)](#fix-5-lut-not-applying-during-playback)
3. [Fix #2: Trim Marker Consolidation (HIGH)](#fix-2-trim-marker-consolidation)
4. [Fix #6: LUT Auto-Learning Not Cascading (CRITICAL)](#fix-6-lut-auto-learning-not-cascading)
5. [Fix #3: Hotkey Implementation (HIGH)](#fix-3-hotkey-implementation)
6. [Fix #1: Center Workflow Nodes (MEDIUM)](#fix-1-center-workflow-nodes)
7. [Testing Strategy](#testing-strategy)
8. [Implementation Order and Dependencies](#implementation-order-and-dependencies)

---

## Fix #4: Play Button Erratic Behavior

### Priority: CRITICAL
### Estimated Time: 2 hours
### File: `Views/RowSubviews/PlayerView.swift`

### Root Cause Analysis

**Current Issues Identified:**

1. **Time Observer Issues** (Lines 474-514):
   - Time observer updates `currentPosition` every 0.1 seconds
   - Each update triggers UI re-renders
   - Seeking happens inside the time observer callback (lines 496-509)
   - This creates a race condition: observer seeks → player plays → observer detects wrong position → seeks again

2. **Playback Limiting Logic** (Lines 492-509):
   - The observer checks if `currentSeconds >= endTime` (line 494)
   - The observer also checks if `currentSeconds < startTime` (line 505)
   - **BUG**: When playback reaches end time, it seeks to start (line 497), but this happens DURING playback
   - The seek operation is asynchronous, causing the player to continue playing a few frames
   - This creates the "skip randomly" effect

3. **Player Setup Issues** (Lines 455-465):
   - `startPlayback()` seeks to trim start, THEN sets up time observer
   - The seek completion handler is async, creating potential race conditions
   - Player may start playing before observer is fully set up

### Implementation Steps

#### Step 1: Fix Time Observer Setup
**Location**: Lines 474-514

**Changes Required**:
```swift
// BEFORE (Lines 474-514)
private func setupTimeObserver() {
    guard let player = player else { return }

    // Remove existing observer
    removeTimeObserver()

    // Add periodic observer to check if we've reached trim end
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
        guard let player = player else { return }

        let currentSeconds = CMTimeGetSeconds(time)
        let normalizedPosition = currentSeconds / asset.duration

        // Update current position for UI
        currentPosition = normalizedPosition

        let endTime = asset.duration * localTrimEnd

        // Stop playback if we've reached or passed the trim end
        if currentSeconds >= endTime {
            player.pause()
            // Seek back to trim start for next play
            let startTime = CMTime(seconds: asset.duration * localTrimStart, preferredTimescale: 600)
            player.seek(to: startTime)
            currentPosition = localTrimStart
            isPlaying = false
        }

        // Also ensure we don't play before trim start
        let startTime = asset.duration * localTrimStart
        if currentSeconds < startTime {
            let seekTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: seekTime)
            currentPosition = localTrimStart
        }
    }

    // Track which player owns this observer
    observerPlayer = player
}

// AFTER (New implementation)
private func setupTimeObserver() {
    guard let player = player else { return }

    // Remove existing observer
    removeTimeObserver()

    // Add periodic observer - ONLY update UI, don't control playback
    let interval = CMTime(seconds: 0.033, preferredTimescale: 600) // ~30fps update rate
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
        guard let self = self else { return }

        let currentSeconds = CMTimeGetSeconds(time)
        let normalizedPosition = currentSeconds / self.asset.duration

        // Update current position for UI ONLY
        Task { @MainActor in
            self.currentPosition = normalizedPosition
        }

        // Check if we've reached or passed the trim end
        let endTime = self.asset.duration * self.localTrimEnd
        if currentSeconds >= endTime - 0.05 { // Stop slightly before end to avoid overshoot
            Task { @MainActor in
                player.pause()
                self.isPlaying = false
                // Seek back to trim start for next play
                let startTime = CMTime(seconds: self.asset.duration * self.localTrimStart, preferredTimescale: 600)
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                self.currentPosition = self.localTrimStart
            }
        }
    }

    // Track which player owns this observer
    observerPlayer = player
}
```

**Why This Fixes It**:
- Reduces time observer interval from 0.1s to 0.033s (30fps) for smoother updates
- Removes the "seek if before start" logic that causes skipping
- Uses `Task { @MainActor in }` to ensure UI updates happen on main thread
- Stops playback slightly before end time (0.05s buffer) to avoid overshooting
- Uses precise seek tolerances (.zero) to ensure accurate positioning

#### Step 2: Fix Playback Start Logic
**Location**: Lines 455-465

**Changes Required**:
```swift
// BEFORE (Lines 455-465)
private func startPlayback() {
    guard let player = player else { return }

    // Seek to trim start before playing
    let startTime = CMTime(seconds: asset.duration * localTrimStart, preferredTimescale: 600)
    player.seek(to: startTime) { _ in
        // Set up periodic observer to constrain playback
        self.setupTimeObserver()
        self.isPlaying = true
    }
}

// AFTER (New implementation)
private func startPlayback() {
    guard let player = player else { return }

    // Set up time observer FIRST
    setupTimeObserver()

    // Then seek to trim start with precise tolerances
    let startTime = CMTime(seconds: asset.duration * localTrimStart, preferredTimescale: 600)
    player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
        guard let self = self, finished else { return }

        Task { @MainActor in
            // Only start playing if seek completed successfully
            self.isPlaying = true
            player.play()
        }
    }
}
```

**Why This Fixes It**:
- Sets up time observer BEFORE seeking, ensuring it's ready when playback starts
- Uses precise seek tolerances to ensure exact start position
- Explicitly calls `player.play()` only after successful seek completion
- Uses weak self to avoid retain cycles

#### Step 3: Add Boundary Time Observer for Precise Stop
**Location**: Add new method after `setupTimeObserver()`

**New Method to Add**:
```swift
private func setupBoundaryObserver() {
    guard let player = player else { return }

    // Remove any existing boundary observer
    if let boundaryObserver = self.boundaryObserver {
        player.removeTimeObserver(boundaryObserver)
    }

    // Create boundary time for trim end
    let endTime = CMTime(seconds: asset.duration * localTrimEnd, preferredTimescale: 600)

    // Add boundary observer - fires exactly when we hit the end time
    boundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) { [weak self] in
        guard let self = self else { return }

        Task { @MainActor in
            player.pause()
            self.isPlaying = false

            // Seek back to trim start for next play
            let startTime = CMTime(seconds: self.asset.duration * self.localTrimStart, preferredTimescale: 600)
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            self.currentPosition = self.localTrimStart
        }
    }
}
```

**Add State Variable**:
```swift
// Add to state variables at top of PlayerView (around line 21)
@State private var boundaryObserver: Any?
```

**Update `startPlayback()` to call boundary observer**:
```swift
private func startPlayback() {
    guard let player = player else { return }

    // Set up observers FIRST
    setupTimeObserver()
    setupBoundaryObserver()

    // Then seek and play...
    // (rest of implementation from Step 2)
}
```

**Update `removeTimeObserver()` to remove boundary observer**:
```swift
private func removeTimeObserver() {
    guard let observer = timeObserver else { return }

    // Try to remove from the current player first (if it exists)
    if let currentPlayer = player {
        currentPlayer.removeTimeObserver(observer)

        // Also remove boundary observer
        if let boundaryObs = boundaryObserver {
            currentPlayer.removeTimeObserver(boundaryObs)
            boundaryObserver = nil
        }
    } else if let ownerPlayer = observerPlayer {
        // Fallback to owner player if current player is nil
        ownerPlayer.removeTimeObserver(observer)

        if let boundaryObs = boundaryObserver {
            ownerPlayer.removeTimeObserver(boundaryObs)
            boundaryObserver = nil
        }
    }

    // Clear references
    timeObserver = nil
    observerPlayer = nil
}
```

### Test Cases

1. **Test smooth playback from in to out**:
   - Input: Video with trim start = 0.2, trim end = 0.8
   - Expected: Video plays smoothly from 20% to 80% without skipping
   - Validation: Visual inspection + time observer logs

2. **Test playback stops exactly at out point**:
   - Input: Video with trim end = 0.5
   - Expected: Playback stops at exactly 50% mark
   - Validation: Check `currentPosition` when playback stops

3. **Test play/pause/play cycle**:
   - Input: Play video, pause mid-playback, play again
   - Expected: Resumes from pause point, plays to end, stops correctly
   - Validation: No frame skipping, correct resume position

4. **Test rapid trim changes during playback**:
   - Input: Play video, quickly change trim end point
   - Expected: Playback continues smoothly, stops at new trim end
   - Validation: No crashes, no erratic behavior

### Dependencies
- None (foundational fix)

---

## Fix #5: LUT Not Applying During Playback

### Priority: CRITICAL
### Estimated Time: 2.5 hours
### Files: `Views/RowSubviews/PlayerView.swift`, `Services/LUTManager.swift`

### Root Cause Analysis

**Current Issues Identified:**

1. **Preview vs Playback Rendering Paths** (Lines 32-62):
   - When `isPlaying = true`: Shows `CustomVideoPlayerView` (line 33-42)
   - When `isPlaying = false`: Shows preview image with LUT applied (line 44-61)
   - **BUG**: `CustomVideoPlayerView` renders AVPlayer directly via `AVPlayerLayer` (lines 670-691)
   - `AVPlayerLayer` does NOT apply any CIFilter or video composition
   - LUT is ONLY applied to still images via `applyLUTToImage()` (lines 413-451)

2. **Missing Video Composition**:
   - The player needs an `AVVideoComposition` with a `CIFilter` compositor to apply LUT during playback
   - Currently, the player is created with just `AVPlayer(url: url)` (line 338)
   - No video composition is attached

3. **LUT Manager Has Filter Creation** (LUTManager.swift):
   - `createLUTFilter(for:)` exists (lines 411-447) but is never used for playback
   - This method creates a reusable CIFilter for video compositions

### Implementation Steps

#### Step 1: Create AVVideoComposition with LUT Filter
**Location**: Add new method to PlayerView (after `applyLUTToImage()`)

**New Method**:
```swift
// Add after line 451 in PlayerView.swift
private func createLUTVideoComposition(for avAsset: AVAsset, lutId: String?) async -> AVVideoComposition? {
    print("🎨 Creating video composition with LUT for playback")
    print("   LUT ID: \(lutId ?? "nil")")

    // No LUT selected - return nil (use default rendering)
    guard let lutIdString = lutId,
          !lutIdString.isEmpty,
          let lutUUID = UUID(uuidString: lutIdString),
          let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == lutUUID }) else {
        print("   ❌ No LUT selected for video composition")
        return nil
    }

    print("   ✅ Found LUT: \(selectedLUT.name)")

    // Create LUT filter (without input image)
    guard let lutFilter = lutManager.createLUTFilter(for: selectedLUT) else {
        print("   ❌ Failed to create LUT filter")
        return nil
    }

    print("   ✅ LUT filter created successfully")

    // Get video track for composition
    guard let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first else {
        print("   ❌ No video track found")
        return nil
    }

    let naturalSize = try? await videoTrack.load(.naturalSize)
    let preferredTransform = try? await videoTrack.load(.preferredTransform)

    print("   ✅ Video track loaded: size=\(naturalSize ?? .zero)")

    // Create video composition with custom compositor
    let composition = AVMutableVideoComposition(asset: avAsset) { request in
        // Get source frame
        let sourceImage = request.sourceImage.clampedToExtent()

        // Apply LUT filter
        lutFilter.setValue(sourceImage, forKey: kCIInputImageKey)

        // Get output image
        if let outputImage = lutFilter.outputImage {
            // Crop to original extent to avoid edge artifacts
            let croppedImage = outputImage.cropped(to: request.sourceImage.extent)
            request.finish(with: croppedImage, context: nil)
        } else {
            // Fallback to source if LUT fails
            request.finish(with: sourceImage, context: nil)
        }
    }

    // Configure composition properties
    if let size = naturalSize {
        composition.renderSize = size
    }
    composition.frameDuration = CMTime(value: 1, timescale: 30) // 30fps

    print("   ✅ Video composition created successfully")
    return composition
}
```

#### Step 2: Apply Video Composition to Player
**Location**: Modify `loadThumbnailAndPlayer()` method (lines 327-377)

**Changes Required**:
```swift
// BEFORE (Lines 327-377)
private func loadThumbnailAndPlayer() {
    guard let url = asset.fileURL else {
        print("Invalid file path for asset: \(asset.fileName ?? "unknown")")
        return
    }

    // Remove existing time observer before creating new player
    removeTimeObserver()

    // Create player - always create it, security scope is handled by the file system
    _ = url.startAccessingSecurityScopedResource()
    let newPlayer = AVPlayer(url: url)

    // Enable automatic waiting to minimize stalls for smoother playback
    newPlayer.automaticallyWaitsToMinimizeStalling = true

    // Use automatic resource allocation for better performance
    if #available(macOS 12.0, *) {
        newPlayer.audiovisualBackgroundPlaybackPolicy = .automatic
    }

    self.player = newPlayer

    // Generate thumbnail and set up image generator
    Task {
        // ... thumbnail generation code ...
    }
}

// AFTER (Updated implementation)
private func loadThumbnailAndPlayer() {
    guard let url = asset.fileURL else {
        print("Invalid file path for asset: \(asset.fileName ?? "unknown")")
        return
    }

    // Remove existing time observer before creating new player
    removeTimeObserver()

    // Create player - always create it, security scope is handled by the file system
    _ = url.startAccessingSecurityScopedResource()

    // Create AVAsset for composition
    let avAsset = AVAsset(url: url)
    let playerItem = AVPlayerItem(asset: avAsset)
    let newPlayer = AVPlayer(playerItem: playerItem)

    // Enable automatic waiting to minimize stalls for smoother playback
    newPlayer.automaticallyWaitsToMinimizeStalling = true

    // Use automatic resource allocation for better performance
    if #available(macOS 12.0, *) {
        newPlayer.audiovisualBackgroundPlaybackPolicy = .automatic
    }

    self.player = newPlayer

    // Apply video composition with LUT if selected
    Task {
        if let composition = await createLUTVideoComposition(for: avAsset, lutId: asset.selectedLUTId) {
            await MainActor.run {
                playerItem.videoComposition = composition
                print("✅ Video composition with LUT applied to player")
            }
        }

        // Generate thumbnail and set up image generator
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 300)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        await MainActor.run {
            self.imageGenerator = generator
        }

        do {
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)

            // Apply LUT if selected
            let finalImage = await applyLUTToImage(cgImage: cgImage)

            await MainActor.run {
                self.thumbnail = finalImage
            }
        } catch {
            print("Failed to generate thumbnail: \(error)")
        }
    }
}
```

#### Step 3: Update Video Composition When LUT Changes
**Location**: Modify `onChange(of: asset.selectedLUTId)` handler (lines 298-304)

**Changes Required**:
```swift
// BEFORE (Lines 298-304)
.onChange(of: asset.selectedLUTId) { newLUTId in
    // Regenerate thumbnail when LUT changes
    print("🎨 PlayerView: LUT selection changed for \(asset.fileName ?? "unknown")")
    print("   New LUT ID: \(newLUTId ?? "nil")")
    print("   Regenerating thumbnail with new LUT...")
    loadThumbnailAndPlayer()
}

// AFTER (Updated implementation)
.onChange(of: asset.selectedLUTId) { newLUTId in
    // Regenerate thumbnail when LUT changes
    print("🎨 PlayerView: LUT selection changed for \(asset.fileName ?? "unknown")")
    print("   New LUT ID: \(newLUTId ?? "nil")")
    print("   Updating video composition and thumbnail with new LUT...")

    // Stop playback if playing
    if isPlaying {
        player?.pause()
        isPlaying = false
    }

    // Update video composition for playback
    Task {
        guard let player = player,
              let playerItem = player.currentItem,
              let avAsset = playerItem.asset as? AVAsset else {
            print("   ⚠️ No player item found, reloading player...")
            loadThumbnailAndPlayer()
            return
        }

        // Create new video composition with updated LUT
        if let composition = await createLUTVideoComposition(for: avAsset, lutId: newLUTId) {
            await MainActor.run {
                playerItem.videoComposition = composition
                print("   ✅ Video composition updated with new LUT")
            }
        } else {
            // No LUT selected - remove video composition
            await MainActor.run {
                playerItem.videoComposition = nil
                print("   ✅ Video composition removed (no LUT)")
            }
        }

        // Regenerate thumbnail with new LUT
        if let imageGenerator = imageGenerator {
            do {
                let time = CMTime(seconds: asset.duration * currentPosition, preferredTimescale: 600)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let finalImage = await applyLUTToImage(cgImage: cgImage)

                await MainActor.run {
                    self.thumbnail = finalImage
                    print("   ✅ Thumbnail updated with new LUT")
                }
            } catch {
                print("   ❌ Failed to regenerate thumbnail: \(error)")
            }
        }
    }
}
```

### Test Cases

1. **Test LUT applies to paused frame**:
   - Input: Select LUT from dropdown while video is paused
   - Expected: Preview image updates immediately with LUT applied
   - Validation: Visual inspection - colors should change

2. **Test LUT applies during playback**:
   - Input: Start playback, LUT should be visible
   - Expected: Video plays with LUT filter applied throughout
   - Validation: Visual inspection - LUT colors visible during motion

3. **Test LUT change during playback**:
   - Input: Play video, change LUT dropdown mid-playback
   - Expected: Playback pauses, new LUT applies, can resume playback
   - Validation: New LUT visible immediately

4. **Test no LUT selected**:
   - Input: Set LUT dropdown to "None" or empty
   - Expected: Video plays with original colors (no composition)
   - Validation: Original colors visible, no LUT filter

### Dependencies
- **Requires**: Fix #4 (playback stability) completed first
- **Blocks**: Fix #6 (LUT auto-learning cascading)

---

## Fix #2: Trim Marker Consolidation

### Priority: HIGH
### Estimated Time: 1.5 hours
### File: `Views/RowSubviews/PlayerView.swift`

### Root Cause Analysis

**Current State** (Lines 133-268):

1. **Trim Markers Already Triangular**: ✅
   - Lines 166-193: Trim start handle uses `TriangleShape(direction: .right)`
   - Lines 196-223: Trim end handle uses `TriangleShape(direction: .left)`
   - Triangle shapes are defined (lines 695-722)

2. **Markers Already on Same Line as Playhead**: ✅
   - All handles positioned at `y: 10` (lines 170, 200, 230)
   - This places them on the same horizontal line

3. **Playback NOT Limited to In/Out Range**: ❌
   - User can drag playhead handle outside trim range
   - Playback does not respect trim bounds (this is partially addressed in Fix #4)

**Issue Summary**: The UI is mostly correct, but playback limiting needs enforcement.

### Implementation Steps

#### Step 1: Enforce Playback Bounds in Playhead Drag
**Location**: Lines 231-245 (Playhead drag gesture)

**Changes Required**:
```swift
// BEFORE (Lines 231-245)
// Playhead handle
Circle()
    .fill(Color.white)
    .frame(width: 14, height: 14)
    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
    .position(x: handleX, y: 10)
    .gesture(
        DragGesture()
            .onChanged { value in
                // Constrain dragging to trim range
                let rawPosition = value.location.x / trackWidth
                let constrainedPosition = max(localTrimStart, min(localTrimEnd, rawPosition))
                currentPosition = constrainedPosition

                // Seek video to new position
                if let player = player {
                    let seekTime = CMTime(seconds: asset.duration * constrainedPosition, preferredTimescale: 600)
                    player.seek(to: seekTime)
                }
            }
    )

// AFTER (No change needed - already constrained correctly)
// This code is already correct and constrains dragging to trim range
```

**Assessment**: This code is already correct - playhead dragging is constrained to trim range.

#### Step 2: Visual Improvement - Make Playable Range More Obvious
**Location**: Lines 144-163

**Changes Required**:
```swift
// BEFORE (Lines 144-163)
ZStack(alignment: .leading) {
    // Background track (full width, grayed out)
    Rectangle()
        .fill(Color.gray.opacity(0.2))
        .frame(width: trackWidth, height: 4)
        .cornerRadius(2)

    // Playable range track
    Rectangle()
        .fill(Color.gray.opacity(0.4))
        .frame(width: playableWidth, height: 4)
        .position(x: trimStartX + playableWidth / 2, y: 10)
        .cornerRadius(2)

    // Played portion
    Rectangle()
        .fill(Color.blue)
        .frame(width: max(0, handleX - trimStartX), height: 4)
        .position(x: trimStartX + max(0, handleX - trimStartX) / 2, y: 10)
        .cornerRadius(2)

    // ... handles ...
}

// AFTER (Enhanced visual contrast)
ZStack(alignment: .leading) {
    // Background track (full width, grayed out) - make more subtle
    Rectangle()
        .fill(Color.gray.opacity(0.15))
        .frame(width: trackWidth, height: 4)
        .cornerRadius(2)

    // Playable range track - make more prominent
    Rectangle()
        .fill(Color.blue.opacity(0.3))
        .frame(width: playableWidth, height: 4)
        .position(x: trimStartX + playableWidth / 2, y: 10)
        .cornerRadius(2)

    // Played portion - keep strong blue
    Rectangle()
        .fill(Color.blue)
        .frame(width: max(0, handleX - trimStartX), height: 4)
        .position(x: trimStartX + max(0, handleX - trimStartX) / 2, y: 10)
        .cornerRadius(2)

    // ... handles ...
}
```

**Why This Improves UX**:
- Makes playable range (between trim markers) more visually distinct
- Users can clearly see the "active" region where playback will occur

#### Step 3: Add Visual Indicator for Out-of-Bounds Position
**Location**: After line 163, before trim handles

**New Code to Add**:
```swift
// Add visual indicator if playhead is outside trim bounds (should never happen, but defensive)
if currentPosition < localTrimStart || currentPosition > localTrimEnd {
    // Red warning indicator
    Rectangle()
        .fill(Color.red.opacity(0.5))
        .frame(width: 2, height: 20)
        .position(x: handleX, y: 10)
}
```

**Why This Helps**:
- Provides visual feedback if playhead somehow ends up outside bounds
- Helps debugging and user awareness

#### Step 4: Document Playback Limiting Behavior
**Location**: Add comment above `startPlayback()` method (line 455)

**New Comment**:
```swift
// MARK: - Trim-Aware Playback
//
// Playback is constrained to the trim range (localTrimStart to localTrimEnd):
// 1. Playback always starts at trim start position
// 2. Time observer monitors playback and stops at trim end
// 3. Boundary observer provides precise stop at exact trim end time
// 4. Playhead dragging is constrained to trim range only
// 5. Trim marker changes push playhead inside bounds if needed

private func startPlayback() {
    // ... existing code ...
}
```

### Test Cases

1. **Test trim markers are triangles**:
   - Visual: Verify trim start is right-pointing triangle, trim end is left-pointing
   - Validation: Screenshot comparison

2. **Test markers on same line as playhead**:
   - Visual: Verify all three handles (trim start, playhead, trim end) aligned horizontally
   - Validation: Y-position should be identical

3. **Test playback starts at in point**:
   - Input: Set trim start to 0.3, click play
   - Expected: Playback begins at 30% mark
   - Validation: Check `currentPosition` when play starts

4. **Test playback stops at out point**:
   - Input: Set trim end to 0.7, click play
   - Expected: Playback stops at 70% mark
   - Validation: Check `currentPosition` when play stops

5. **Test playhead cannot be dragged outside trim range**:
   - Input: Try to drag playhead before trim start or after trim end
   - Expected: Playhead stops at trim boundary
   - Validation: Check `currentPosition` stays within `localTrimStart` to `localTrimEnd`

### Dependencies
- **Requires**: Fix #4 (playback stability) for proper playback limiting
- **Enhances**: Fix #5 (LUT playback) by ensuring LUT preview shows correct trim range

---

## Fix #6: LUT Auto-Learning Not Cascading

### Priority: CRITICAL
### Estimated Time: 2 hours
### Files: `Services/LUTAutoMapper.swift`, `Views/RowSubviews/PlayerView.swift`, `ViewModels/ContentViewModel.swift`

### Root Cause Analysis

**Current Flow** (when user selects LUT):

1. **User selects LUT in dropdown** (somewhere in UI, likely `EditableFieldsView.swift`)
2. **LUT saved to Core Data**: `asset.selectedLUTId = lutId`
3. **Learning happens**: `LUTManager.shared.learnLUTPreference()` is called (LUTManager.swift line 240-268)
4. **Other videos get dropdown updated**: Auto-mapping applies new LUT ID to `selectedLUTId`
5. **BUG**: Other videos' PlayerViews don't reload because:
   - PlayerView only updates when `asset.selectedLUTId` changes (line 298)
   - But the Core Data object may not trigger change notification if updated in background
   - Preview image is NOT regenerated
   - Video composition is NOT recreated

**Issue**: Core Data change notifications may not propagate to all PlayerViews.

### Implementation Steps

#### Step 1: Add Notification Publisher to LUTManager
**Location**: `Services/LUTManager.swift` - Add after line 46

**New Code**:
```swift
// Add to LUTManager class (after line 46 - after userLUTMappings declaration)

// Notification for when a new LUT preference is learned
static let lutPreferenceLearnedNotification = Notification.Name("LUTPreferenceLearned")

// Published event for learning (SwiftUI-friendly)
@Published var lastLearnedMapping: UserLUTMapping?
```

#### Step 2: Publish Notification When Learning Occurs
**Location**: `Services/LUTManager.swift` - Modify `learnLUTPreference()` (lines 240-268)

**Changes Required**:
```swift
// BEFORE (Lines 257-268)
userLUTMappings[key] = mapping
saveUserMappings()

print("🎓 Learned new LUT preference:")
print("   Gamma: \(gamma)")
print("   Color Space: \(colorSpace)")
print("   Preferred LUT: \(selectedLUT.name)")

return true

// AFTER (Add notification publishing)
userLUTMappings[key] = mapping
saveUserMappings()

print("🎓 Learned new LUT preference:")
print("   Gamma: \(gamma)")
print("   Color Space: \(colorSpace)")
print("   Preferred LUT: \(selectedLUT.name)")

// Publish notification for other views to update
DispatchQueue.main.async {
    self.lastLearnedMapping = mapping
    NotificationCenter.default.post(
        name: Self.lutPreferenceLearnedNotification,
        object: nil,
        userInfo: [
            "gamma": gamma,
            "colorSpace": colorSpace,
            "lutId": selectedLUT.id.uuidString,
            "lutName": selectedLUT.name
        ]
    )
}

return true
```

#### Step 3: Listen for LUT Learning Notifications in PlayerView
**Location**: `Views/RowSubviews/PlayerView.swift` - Add to `onAppear` (line 292)

**Changes Required**:
```swift
// BEFORE (Lines 292-297)
.onAppear {
    loadThumbnailAndPlayer()
}

// AFTER (Add notification observer)
.onAppear {
    loadThumbnailAndPlayer()

    // Listen for LUT preference learning events
    NotificationCenter.default.addObserver(
        forName: LUTManager.lutPreferenceLearnedNotification,
        object: nil,
        queue: .main
    ) { [weak asset] notification in
        guard let asset = asset,
              let userInfo = notification.userInfo,
              let learnedGamma = userInfo["gamma"] as? String,
              let learnedColorSpace = userInfo["colorSpace"] as? String,
              let learnedLUTId = userInfo["lutId"] as? String else {
            return
        }

        // Check if this asset matches the learned camera metadata
        let assetGamma = asset.captureGamma?.lowercased() ?? ""
        let assetColorSpace = asset.captureColorPrimaries?.lowercased() ?? ""

        // Normalize for comparison (same as LUTAutoMapper)
        let normalizedAssetGamma = LUTAutoMapper.normalizeForMatching(assetGamma)
        let normalizedAssetColorSpace = LUTAutoMapper.normalizeForMatching(assetColorSpace)

        if normalizedAssetGamma == learnedGamma && normalizedAssetColorSpace == learnedColorSpace {
            print("🎓 PlayerView: LUT learning notification received for matching asset")
            print("   Asset: \(asset.fileName ?? "unknown")")
            print("   Gamma: \(learnedGamma), ColorSpace: \(learnedColorSpace)")
            print("   New LUT ID: \(learnedLUTId)")

            // Update asset's selectedLUTId (this will trigger onChange)
            Task { @MainActor in
                asset.selectedLUTId = learnedLUTId

                // Save Core Data context
                if let context = asset.managedObjectContext {
                    do {
                        try context.save()
                        print("   ✅ Asset LUT updated and saved")
                    } catch {
                        print("   ❌ Failed to save Core Data: \(error)")
                    }
                }
            }
        }
    }
}
```

#### Step 4: Ensure LUT Auto-Mapping Calls Learning Method
**Location**: Check where LUT auto-mapping is applied (likely in `Services/FileScannerService.swift`)

**Search and verify**:
```bash
# Search for where LUTAutoMapper.findBestLUT is called
grep -r "findBestLUT" --include="*.swift"
```

**Ensure this pattern is followed**:
```swift
// When auto-mapping LUT during scan:
if let autoMappedLUT = LUTAutoMapper.findBestLUT(
    gamma: asset.captureGamma,
    colorSpace: asset.captureColorPrimaries,
    availableLUTs: LUTManager.shared.availableLUTs
) {
    asset.selectedLUTId = autoMappedLUT.id.uuidString
    print("✅ Auto-mapped LUT: \(autoMappedLUT.name)")
}

// When user manually selects LUT (in EditableFieldsView or similar):
if let selectedLUT = lutManager.availableLUTs.first(where: { $0.id == newLUTId }) {
    asset.selectedLUTId = selectedLUT.id.uuidString

    // Learn from this selection
    _ = lutManager.learnLUTPreference(
        gamma: asset.captureGamma,
        colorSpace: asset.captureColorPrimaries,
        selectedLUT: selectedLUT
    )
}
```

#### Step 5: Add Batch Update for All Matching Assets
**Location**: Add new method to `ViewModels/ContentViewModel.swift`

**New Method**:
```swift
// Add to ContentViewModel class
func applyLearnedLUTToMatchingAssets(gamma: String, colorSpace: String, lutId: String) {
    print("🎓 ContentViewModel: Applying learned LUT to all matching assets")
    print("   Gamma: \(gamma), ColorSpace: \(colorSpace)")

    let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

    do {
        let allAssets = try viewContext.fetch(fetchRequest)
        var updatedCount = 0

        for asset in allAssets {
            // Check if asset matches camera metadata
            let assetGamma = asset.captureGamma?.lowercased() ?? ""
            let assetColorSpace = asset.captureColorPrimaries?.lowercased() ?? ""

            let normalizedAssetGamma = LUTAutoMapper.normalizeForMatching(assetGamma)
            let normalizedAssetColorSpace = LUTAutoMapper.normalizeForMatching(assetColorSpace)

            if normalizedAssetGamma == gamma && normalizedAssetColorSpace == colorSpace {
                asset.selectedLUTId = lutId
                updatedCount += 1
            }
        }

        // Save all changes
        try viewContext.save()
        print("   ✅ Updated \(updatedCount) assets with learned LUT")

    } catch {
        print("   ❌ Failed to update assets: \(error)")
    }
}
```

**Call this method when learning occurs** (in notification observer):
```swift
// In ContentViewModel, add notification observer in init():
NotificationCenter.default.addObserver(
    forName: LUTManager.lutPreferenceLearnedNotification,
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let self = self,
          let userInfo = notification.userInfo,
          let gamma = userInfo["gamma"] as? String,
          let colorSpace = userInfo["colorSpace"] as? String,
          let lutId = userInfo["lutId"] as? String else {
        return
    }

    Task { @MainActor in
        self.applyLearnedLUTToMatchingAssets(
            gamma: gamma,
            colorSpace: colorSpace,
            lutId: lutId
        )
    }
}
```

### Test Cases

1. **Test learning updates dropdown**:
   - Input: Video A with S-Log3/S-Gamut3.Cine, select "Sony Rec709" LUT
   - Expected: System learns this preference
   - Validation: Check `userLUTMappings.json` file for new entry

2. **Test other videos get dropdown updated**:
   - Input: Video B with same S-Log3/S-Gamut3.Cine metadata
   - Expected: Dropdown automatically selects "Sony Rec709"
   - Validation: Check `asset.selectedLUTId` equals learned LUT ID

3. **Test other videos get preview updated**:
   - Input: Video B (from test 2)
   - Expected: Preview image (thumbnail) shows LUT applied
   - Validation: Visual inspection - should show color graded image

4. **Test other videos get playback updated**:
   - Input: Play Video B (from test 2)
   - Expected: Playback shows LUT applied throughout
   - Validation: Visual inspection during playback

5. **Test batch update performance**:
   - Input: 100 videos with same metadata, learn LUT
   - Expected: All 100 videos update within 2 seconds
   - Validation: Measure time from learning to last preview update

### Dependencies
- **Requires**: Fix #5 (LUT playback) to ensure video composition updates
- **Enhances**: Overall LUT workflow by making learning truly automatic

---

## Fix #3: Hotkey Implementation

### Priority: HIGH
### Estimated Time: 2.5 hours
### Files: `VideoCullingApp.swift`, `ViewModels/ContentViewModel.swift`, `Views/ContentView.swift`, `Views/PreferencesView.swift`

### Root Cause Analysis

**Current State**:
- No keyboard event monitoring exists
- No hotkey configuration in preferences
- No global actions for navigation, playback, or editing

**Required Hotkeys**:
1. **Left/Right Arrow**: Navigate to previous/next video in filmstrip
2. **Up/Down Arrow**: Navigate in vertical mode (same as Left/Right in horizontal)
3. **Spacebar**: Play/Pause current video
4. **Z**: Set in point (trim start) at current playhead position
5. **X**: Set out point (trim end) at current playhead position
6. **C**: Mark current video for deletion (toggle)

**Configuration**: All hotkeys should be configurable in Preferences

### Implementation Steps

#### Step 1: Create Hotkey Manager
**Location**: Create new file `Services/HotkeyManager.swift`

**New File**:
```swift
//
//  HotkeyManager.swift
//  VideoCullingApp
//

import Foundation
import AppKit
import SwiftUI

// MARK: - Hotkey Action Enum
enum HotkeyAction: String, CaseIterable, Identifiable {
    case previousVideo = "Previous Video"
    case nextVideo = "Next Video"
    case playPause = "Play/Pause"
    case setInPoint = "Set In Point"
    case setOutPoint = "Set Out Point"
    case toggleDeletion = "Toggle Deletion Flag"

    var id: String { rawValue }

    var defaultKey: String {
        switch self {
        case .previousVideo: return "←"
        case .nextVideo: return "→"
        case .playPause: return "Space"
        case .setInPoint: return "z"
        case .setOutPoint: return "x"
        case .toggleDeletion: return "c"
        }
    }

    var defaultKeyCode: UInt16 {
        switch self {
        case .previousVideo: return 123 // Left arrow
        case .nextVideo: return 124 // Right arrow
        case .playPause: return 49 // Space
        case .setInPoint: return 6 // Z
        case .setOutPoint: return 7 // X
        case .toggleDeletion: return 8 // C
        }
    }
}

// MARK: - Hotkey Configuration
struct HotkeyConfig: Codable {
    let action: String
    let keyCode: UInt16
    let modifiers: UInt // NSEvent.ModifierFlags raw value

    var displayString: String {
        var parts: [String] = []

        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 {
            parts.append("⌘")
        }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 {
            parts.append("⌥")
        }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 {
            parts.append("⌃")
        }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 {
            parts.append("⇧")
        }

        // Add key name
        if let action = HotkeyAction(rawValue: action) {
            parts.append(action.defaultKey)
        }

        return parts.joined(separator: "")
    }
}

// MARK: - Hotkey Manager
@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "hotkeysEnabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    private var eventMonitor: Any?
    private var hotkeyConfigs: [String: HotkeyConfig] = [:]
    private let configURL: URL

    // Callback handlers (set by ContentViewModel)
    var onPreviousVideo: (() -> Void)?
    var onNextVideo: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onSetInPoint: (() -> Void)?
    var onSetOutPoint: (() -> Void)?
    var onToggleDeletion: (() -> Void)?

    private init() {
        // Set up config file location
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VideoCullingApp", isDirectory: true)
        configURL = appDirectory.appendingPathComponent("hotkeyConfig.json")

        loadConfiguration()

        isEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true

        if isEnabled {
            startMonitoring()
        }
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Configuration Management

    private func loadConfiguration() {
        if FileManager.default.fileExists(atPath: configURL.path),
           let data = try? Data(contentsOf: configURL),
           let configs = try? JSONDecoder().decode([HotkeyConfig].self, from: data) {
            hotkeyConfigs = Dictionary(uniqueKeysWithValues: configs.map { ($0.action, $0) })
            print("✅ Loaded \(hotkeyConfigs.count) hotkey configurations")
        } else {
            // Load defaults
            loadDefaultConfiguration()
        }
    }

    private func loadDefaultConfiguration() {
        for action in HotkeyAction.allCases {
            let config = HotkeyConfig(
                action: action.rawValue,
                keyCode: action.defaultKeyCode,
                modifiers: 0 // No modifiers by default
            )
            hotkeyConfigs[action.rawValue] = config
        }
        saveConfiguration()
    }

    func saveConfiguration() {
        let configs = Array(hotkeyConfigs.values)
        if let data = try? JSONEncoder().encode(configs) {
            try? data.write(to: configURL)
            print("✅ Saved hotkey configuration")
        }
    }

    func getConfig(for action: HotkeyAction) -> HotkeyConfig? {
        return hotkeyConfigs[action.rawValue]
    }

    func updateConfig(for action: HotkeyAction, keyCode: UInt16, modifiers: UInt) {
        let config = HotkeyConfig(action: action.rawValue, keyCode: keyCode, modifiers: modifiers)
        hotkeyConfigs[action.rawValue] = config
        saveConfiguration()
    }

    // MARK: - Event Monitoring

    private func startMonitoring() {
        // Remove existing monitor
        stopMonitoring()

        // Add local event monitor for key down events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Check if event matches any configured hotkey
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue

            // Find matching hotkey
            for (actionName, config) in self.hotkeyConfigs {
                if config.keyCode == keyCode && config.modifiers == modifiers {
                    // Execute action
                    Task { @MainActor in
                        self.executeAction(actionName)
                    }
                    // Consume event (prevent default behavior)
                    return nil
                }
            }

            // Let event pass through if no hotkey matched
            return event
        }

        print("✅ Hotkey monitoring started")
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("⏹ Hotkey monitoring stopped")
        }
    }

    private func executeAction(_ actionName: String) {
        guard let action = HotkeyAction(rawValue: actionName) else { return }

        print("⌨️ Executing hotkey action: \(action.rawValue)")

        switch action {
        case .previousVideo:
            onPreviousVideo?()
        case .nextVideo:
            onNextVideo?()
        case .playPause:
            onPlayPause?()
        case .setInPoint:
            onSetInPoint?()
        case .setOutPoint:
            onSetOutPoint?()
        case .toggleDeletion:
            onToggleDeletion?()
        }
    }
}
```

#### Step 2: Add Hotkey Actions to ContentViewModel
**Location**: `ViewModels/ContentViewModel.swift` - Add methods after `scanInputFolder()`

**New Methods**:
```swift
// MARK: - Hotkey Actions

var selectedAssetIndex: Int = 0 // Track currently selected asset
var allAssets: [ManagedVideoAsset] = [] // Cache of all assets for navigation

func selectPreviousVideo() {
    guard !allAssets.isEmpty else { return }
    selectedAssetIndex = max(0, selectedAssetIndex - 1)
    print("⌨️ Navigate to previous video: index \(selectedAssetIndex)")
    // Trigger UI update via notification
    NotificationCenter.default.post(name: .navigateToVideo, object: selectedAssetIndex)
}

func selectNextVideo() {
    guard !allAssets.isEmpty else { return }
    selectedAssetIndex = min(allAssets.count - 1, selectedAssetIndex + 1)
    print("⌨️ Navigate to next video: index \(selectedAssetIndex)")
    // Trigger UI update via notification
    NotificationCenter.default.post(name: .navigateToVideo, object: selectedAssetIndex)
}

func togglePlayPause() {
    print("⌨️ Toggle play/pause")
    // Trigger via notification (PlayerView will handle)
    NotificationCenter.default.post(name: .togglePlayPause, object: nil)
}

func setInPointAtCurrentPosition() {
    guard selectedAssetIndex < allAssets.count else { return }
    let asset = allAssets[selectedAssetIndex]
    print("⌨️ Set in point for: \(asset.fileName ?? "unknown")")
    // Trigger via notification with asset
    NotificationCenter.default.post(name: .setInPoint, object: asset)
}

func setOutPointAtCurrentPosition() {
    guard selectedAssetIndex < allAssets.count else { return }
    let asset = allAssets[selectedAssetIndex]
    print("⌨️ Set out point for: \(asset.fileName ?? "unknown")")
    // Trigger via notification with asset
    NotificationCenter.default.post(name: .setOutPoint, object: asset)
}

func toggleDeletionFlag() {
    guard selectedAssetIndex < allAssets.count else { return }
    let asset = allAssets[selectedAssetIndex]
    asset.isFlaggedForDeletion.toggle()

    if let context = asset.managedObjectContext {
        do {
            try context.save()
            print("⌨️ Toggled deletion flag: \(asset.isFlaggedForDeletion) for \(asset.fileName ?? "unknown")")
        } catch {
            print("❌ Failed to save deletion flag: \(error)")
        }
    }
}

// Call this after scanning to populate allAssets
func updateAssetCache() {
    let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldestFirst)]

    do {
        allAssets = try viewContext.fetch(fetchRequest)
        selectedAssetIndex = 0
        print("✅ Updated asset cache: \(allAssets.count) assets")
    } catch {
        print("❌ Failed to fetch assets: \(error)")
    }
}
```

**Add notification names** (at top of ContentViewModel.swift file):
```swift
// Add after imports
extension Notification.Name {
    static let navigateToVideo = Notification.Name("navigateToVideo")
    static let togglePlayPause = Notification.Name("togglePlayPause")
    static let setInPoint = Notification.Name("setInPoint")
    static let setOutPoint = Notification.Name("setOutPoint")
}
```

#### Step 3: Wire Up Hotkey Manager to ContentViewModel
**Location**: `ViewModels/ContentViewModel.swift` - Modify `init()`

**Changes**:
```swift
init(context: NSManagedObjectContext) {
    self.viewContext = context
    self.scannerService = FileScannerService(context: context)
    self.processingService = ProcessingService(context: context)

    // Wire up hotkey handlers
    Task { @MainActor in
        HotkeyManager.shared.onPreviousVideo = { [weak self] in
            self?.selectPreviousVideo()
        }
        HotkeyManager.shared.onNextVideo = { [weak self] in
            self?.selectNextVideo()
        }
        HotkeyManager.shared.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        HotkeyManager.shared.onSetInPoint = { [weak self] in
            self?.setInPointAtCurrentPosition()
        }
        HotkeyManager.shared.onSetOutPoint = { [weak self] in
            self?.setOutPointAtCurrentPosition()
        }
        HotkeyManager.shared.onToggleDeletion = { [weak self] in
            self?.toggleDeletionFlag()
        }
    }

    // ... existing code ...
}
```

#### Step 4: Handle Hotkey Notifications in PlayerView
**Location**: `Views/RowSubviews/PlayerView.swift` - Add to `onAppear`

**Changes**:
```swift
.onAppear {
    loadThumbnailAndPlayer()

    // ... existing LUT learning observer ...

    // Listen for play/pause hotkey
    NotificationCenter.default.addObserver(
        forName: .togglePlayPause,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        guard let self = self else { return }

        Task { @MainActor in
            if self.isPlaying {
                self.player?.pause()
                self.isPlaying = false
            } else {
                self.startPlayback()
            }
        }
    }

    // Listen for set in point hotkey
    NotificationCenter.default.addObserver(
        forName: .setInPoint,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let self = self,
              let targetAsset = notification.object as? ManagedVideoAsset,
              targetAsset.objectID == self.asset.objectID else {
            return
        }

        Task { @MainActor in
            // Set trim start to current playhead position
            self.localTrimStart = self.currentPosition
            self.asset.trimStartTime = self.currentPosition

            // Save to Core Data
            if let context = self.asset.managedObjectContext {
                try? context.save()
            }

            print("⌨️ Set in point to: \(self.currentPosition)")
        }
    }

    // Listen for set out point hotkey
    NotificationCenter.default.addObserver(
        forName: .setOutPoint,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let self = self,
              let targetAsset = notification.object as? ManagedVideoAsset,
              targetAsset.objectID == self.asset.objectID else {
            return
        }

        Task { @MainActor in
            // Set trim end to current playhead position
            self.localTrimEnd = self.currentPosition
            self.asset.trimEndTime = self.currentPosition

            // Save to Core Data
            if let context = self.asset.managedObjectContext {
                try? context.save()
            }

            print("⌨️ Set out point to: \(self.currentPosition)")
        }
    }
}
```

#### Step 5: Add Hotkey Configuration to PreferencesView
**Location**: `Views/PreferencesView.swift` - Add new section

**New Section** (add after "Advanced" section):
```swift
// Add to PreferenceSection enum
case hotkeys = "Hotkeys"

// Add icon for hotkeys
var icon: String {
    switch self {
    // ... existing cases ...
    case .hotkeys: return "keyboard"
    }
}

// Add hotkeys section UI (in PreferencesView body)
if selectedSection == .hotkeys {
    HotkeyPreferencesView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

**New HotkeyPreferencesView** (add at end of PreferencesView.swift):
```swift
// MARK: - Hotkey Preferences View
struct HotkeyPreferencesView: View {
    @StateObject private var hotkeyManager = HotkeyManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.bold)

            Toggle("Enable Hotkeys", isOn: $hotkeyManager.isEnabled)
                .toggleStyle(.switch)

            Divider()

            Text("Current Hotkey Bindings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(HotkeyAction.allCases) { action in
                    HStack {
                        Text(action.rawValue)
                            .frame(width: 180, alignment: .leading)

                        if let config = hotkeyManager.getConfig(for: action) {
                            Text(config.displayString)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }

                        Spacer()

                        Button("Reset to Default") {
                            hotkeyManager.updateConfig(
                                for: action,
                                keyCode: action.defaultKeyCode,
                                modifiers: 0
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Spacer()

            Text("Note: Hotkeys work when the application window is focused. Some system hotkeys may override these bindings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

### Test Cases

1. **Test Left/Right navigation**:
   - Input: Load 5 videos, press Right arrow 3 times
   - Expected: Selection moves to 4th video
   - Validation: Check `selectedAssetIndex == 3`

2. **Test Spacebar play/pause**:
   - Input: Press Spacebar (video not playing)
   - Expected: Video starts playing
   - Input: Press Spacebar again
   - Expected: Video pauses
   - Validation: Check `isPlaying` state toggles

3. **Test Z sets in point**:
   - Input: Play video to 30% mark, press Z
   - Expected: Trim start marker moves to 30% position
   - Validation: Check `asset.trimStartTime == 0.3`

4. **Test X sets out point**:
   - Input: Play video to 70% mark, press X
   - Expected: Trim end marker moves to 70% position
   - Validation: Check `asset.trimEndTime == 0.7`

5. **Test C marks for deletion**:
   - Input: Press C (not flagged)
   - Expected: Video gets deletion flag
   - Input: Press C again
   - Expected: Deletion flag removed
   - Validation: Check `asset.isFlaggedForDeletion` toggles

6. **Test hotkey configuration in preferences**:
   - Input: Open Preferences → Hotkeys
   - Expected: All hotkeys listed with current bindings
   - Validation: Visual inspection of UI

### Dependencies
- **Requires**: Fix #4 (playback stability) for play/pause hotkey
- **Enhances**: Overall workflow efficiency

---

## Fix #1: Center Workflow Nodes

### Priority: MEDIUM
### Estimated Time: 15 minutes
### File: `Views/CompactWorkflowView.swift`

### Root Cause Analysis

**Current Issue** (Lines 24-125):
- Workflow nodes (Source → Staging → Output → FCP) are not centered
- Missing leading `Spacer()` to push content to center
- There's already a `Spacer()` at line 26, but duplicated at lines 125-127

**Simple Fix**: Ensure proper centering with balanced spacers

### Implementation Steps

#### Step 1: Fix Spacer Layout
**Location**: Lines 24-128

**Changes Required**:
```swift
// BEFORE (Lines 24-128)
HStack(spacing: 16) {
    // Workflow nodes (centered with more spacing)
    Spacer()

    HStack(spacing: 14) {
        // ... workflow nodes ...
    }

    Spacer()

    Spacer()

    // Close Folder button
    Button(action: { ... })

    // Big process button
    Button(action: { ... })
}

// AFTER (Proper centering)
HStack(spacing: 16) {
    // Workflow nodes (centered with more spacing)
    Spacer()

    HStack(spacing: 14) {
        // ... workflow nodes ...
    }

    Spacer()

    // Close Folder button
    Button(action: { ... })

    // Big process button
    Button(action: { ... })
}
```

**Summary**: Remove duplicate `Spacer()` at lines 125-127. The existing spacers (line 26 and line 125) already provide proper centering.

### Test Cases

1. **Test workflow nodes centered on load**:
   - Input: Launch app
   - Expected: Workflow nodes appear centered in toolbar
   - Validation: Visual inspection - equal spacing on left and right

2. **Test workflow nodes stay centered on resize**:
   - Input: Resize window to different widths
   - Expected: Workflow nodes remain centered
   - Validation: Visual inspection at 1024px, 1440px, 1920px widths

3. **Test spacing consistent**:
   - Input: Measure distances between nodes
   - Expected: All node spacing = 14px (from HStack spacing)
   - Validation: Screenshot measurement

### Dependencies
- None (independent UI fix)

---

## Testing Strategy

### Phase 1: Unit Testing (Per Fix)

**For Each Fix**:
1. Implement the fix completely
2. Run manual test cases listed in fix documentation
3. Verify expected behavior matches actual behavior
4. Log any failures and fix immediately before proceeding

**Test Environment**:
- macOS 13.0+ (target OS)
- Sample videos:
  - 1080p MP4 (H.264)
  - 4K MP4 (H.265)
  - Sony camera footage with XML sidecars
  - Videos with S-Log3/S-Gamut3.Cine metadata

### Phase 2: Integration Testing

**Test Scenarios**:

1. **Playback + LUT + Trim Workflow**:
   - Load video with LUT auto-mapped
   - Set trim points with Z/X hotkeys
   - Play video with Spacebar
   - Verify LUT applies during playback
   - Verify playback stops at trim out point

2. **LUT Learning Cascade**:
   - Load 5 videos with same camera metadata
   - Manually select LUT for Video #1
   - Verify Videos #2-5 auto-update dropdown
   - Verify Videos #2-5 auto-update preview
   - Verify Videos #2-5 show LUT during playback

3. **Hotkey Navigation Workflow**:
   - Load 10 videos
   - Use Right arrow to navigate through all
   - Use Z/X to set trim points on Video #5
   - Use C to mark Videos #3, #7 for deletion
   - Use Spacebar to preview Video #5

4. **UI Consistency**:
   - Verify workflow nodes centered at all times
   - Verify trim markers aligned with playhead
   - Verify all hotkeys work regardless of UI state

### Phase 3: 5x Randomized Test Cycles

**Automated Test Suite** (Create in Swift):
```swift
// VideoCullingAppTests/CriticalFixesTests.swift

import XCTest
@testable import VideoCullingApp

class CriticalFixesTests: XCTestCase {

    func testPlaybackSmoothness() {
        // Test Fix #4: Playback should not skip frames
        // ... test implementation ...
    }

    func testLUTAppliesDuringPlayback() {
        // Test Fix #5: LUT visible during playback
        // ... test implementation ...
    }

    func testTrimMarkersLimitPlayback() {
        // Test Fix #2: Playback constrained to trim range
        // ... test implementation ...
    }

    func testLUTLearningCascades() {
        // Test Fix #6: Learning updates all matching videos
        // ... test implementation ...
    }

    func testHotkeysExecuteActions() {
        // Test Fix #3: All hotkeys trigger correct actions
        // ... test implementation ...
    }

    func testWorkflowNodesCentered() {
        // Test Fix #1: UI layout correct
        // ... test implementation ...
    }
}
```

**Randomization Strategy**:
1. Run tests in random order 5 times
2. Each cycle must pass 100% of tests
3. Any failure stops testing, must be fixed immediately
4. Continue until 5 clean passes achieved

**Test Execution**:
```bash
# Run test suite 5 times
for i in {1..5}; do
    echo "=== Test Cycle $i ==="
    xcodebuild test \
        -scheme VideoCullingApp \
        -destination 'platform=macOS' \
        -test-iteration-mode randomized \
        -test-iterations 1

    if [ $? -ne 0 ]; then
        echo "❌ Test cycle $i FAILED - stopping"
        exit 1
    fi
done

echo "✅ All 5 test cycles PASSED"
```

### Phase 4: Manual Verification

**Final Checklist**:

- [ ] Fix #4: Play button plays smoothly from in to out point
- [ ] Fix #5: LUT applies to both paused frames AND during playback
- [ ] Fix #2: Trim markers are triangles on same line as playhead
- [ ] Fix #2: Playback automatically limited to in/out range
- [ ] Fix #6: LUT learning updates dropdown for other videos
- [ ] Fix #6: LUT learning updates preview for other videos
- [ ] Fix #6: LUT learning updates playback for other videos
- [ ] Fix #3: Left/Right arrow keys navigate videos
- [ ] Fix #3: Spacebar toggles play/pause
- [ ] Fix #3: Z sets in point at playhead position
- [ ] Fix #3: X sets out point at playhead position
- [ ] Fix #3: C marks video for deletion
- [ ] Fix #1: Workflow nodes centered in toolbar

**User Acceptance Testing**:
1. Complete a full video culling workflow (10-20 videos)
2. Use only hotkeys for navigation and editing
3. Verify LUT previews accurate
4. Verify playback smooth and LUT-applied
5. Verify trim markers behave as expected

---

## Implementation Order and Dependencies

### Dependency Graph

```
Fix #4 (Playback)
    ↓
Fix #5 (LUT Playback) ────┐
    ↓                     ↓
Fix #6 (LUT Learning) ←───┘
    ↓
Fix #2 (Trim Markers)
    ↓
Fix #3 (Hotkeys)
    ↓
Fix #1 (Centering)
```

### Recommended Implementation Order

**Day 1: Critical Playback Fixes (4-5 hours)**

1. **Fix #4**: Play Button Erratic Behavior (2 hours)
   - Most critical bug blocking all other testing
   - Must be stable before testing LUT playback

2. **Fix #5**: LUT Not Applying During Playback (2.5 hours)
   - Depends on Fix #4 for stable playback
   - Required for Fix #6 to work properly

**Day 2: Workflow Improvements (4-5 hours)**

3. **Fix #6**: LUT Auto-Learning Cascading (2 hours)
   - Depends on Fix #5 for video composition
   - Major UX improvement

4. **Fix #2**: Trim Marker Consolidation (1.5 hours)
   - Enhances playback behavior from Fix #4
   - Minor UI polish

5. **Fix #3**: Hotkey Implementation (2.5 hours)
   - Depends on all playback fixes being stable
   - Major productivity improvement

6. **Fix #1**: Center Workflow Nodes (15 minutes)
   - Independent fix, can be done anytime
   - Quick UI polish

**Testing**: 2 hours (5x randomized cycles + manual verification)

---

## Success Criteria

### Technical Metrics

1. **Playback Frame Rate**: Maintain 24-30fps during playback with LUT applied
2. **LUT Application Time**: < 100ms to apply LUT filter to video composition
3. **Learning Cascade Time**: < 2 seconds to update all matching videos (batch of 100)
4. **Hotkey Response Time**: < 50ms from key press to action execution
5. **UI Render Time**: < 16ms (60fps) for all UI updates

### User Experience Metrics

1. **Zero Frame Skipping**: Playback must be smooth without random jumps
2. **Accurate LUT Preview**: Preview image matches playback appearance
3. **Instant Feedback**: Hotkeys execute immediately with visible feedback
4. **Workflow Efficiency**: 50%+ reduction in mouse clicks for common tasks

### Quality Metrics

1. **Test Pass Rate**: 100% on all test cases
2. **Regression Tests**: 0 failures in existing test suite
3. **Memory Leaks**: 0 detected during playback sessions
4. **CPU Usage**: < 80% during playback with LUT on 2019 MacBook Pro

---

## Risk Assessment and Mitigation

### High Risk Areas

1. **AVPlayer Time Observer Race Conditions** (Fix #4)
   - **Risk**: Time observer and seek operations conflict
   - **Mitigation**: Use boundary observer for precise end-of-playback detection
   - **Fallback**: Increase time observer interval if performance issues

2. **Video Composition Performance** (Fix #5)
   - **Risk**: Real-time LUT application may drop frames on older Macs
   - **Mitigation**: Use hardware-accelerated CIFilter rendering
   - **Fallback**: Provide "disable LUT during playback" option in preferences

3. **Core Data Change Propagation** (Fix #6)
   - **Risk**: Notification-based updates may not reach all views
   - **Mitigation**: Use both NotificationCenter and batch Core Data updates
   - **Fallback**: Add manual "refresh all previews" button

4. **Hotkey Conflicts** (Fix #3)
   - **Risk**: System hotkeys may override app hotkeys
   - **Mitigation**: Use local event monitor (app-scoped only)
   - **Fallback**: Make all hotkeys configurable

### Rollback Plan

If any fix causes critical issues:

1. **Immediate**: Comment out failing code
2. **Git revert**: Revert to last known good commit
3. **Isolate**: Test fix in isolation branch
4. **Re-implement**: Fix root cause and re-test

---

## File Summary for Implementation

**Files to Create**:
- `/Services/HotkeyManager.swift` (Fix #3)

**Files to Modify**:
- `/Views/RowSubviews/PlayerView.swift` (Fixes #4, #5, #6, #3)
- `/Services/LUTManager.swift` (Fixes #5, #6)
- `/Services/LUTAutoMapper.swift` (Fix #6)
- `/ViewModels/ContentViewModel.swift` (Fixes #6, #3)
- `/Views/PreferencesView.swift` (Fix #3)
- `/Views/CompactWorkflowView.swift` (Fix #1)
- `/VideoCullingApp.swift` (Fix #3 - optional, for app-level event monitoring)

**Estimated Total Lines Changed**: ~800 lines
- New code: ~500 lines (HotkeyManager + video composition logic)
- Modified code: ~300 lines (playback logic + notifications)

---

## Next Steps

1. **Review this plan** with stakeholders
2. **Set up test environment** with sample videos
3. **Create feature branch**: `git checkout -b critical-fixes-implementation`
4. **Begin implementation** following order above
5. **Run tests after each fix**
6. **Create pull request** when all fixes complete
7. **QA testing** before merge to main

---

**Document Version**: 1.0
**Last Updated**: 2025-11-19
**Author**: Feature Implementation Planner Agent
**Status**: Ready for Implementation
