# Critical Fixes Implementation Plan

**Date**: 2025-11-19
**Status**: 🔴 IN PROGRESS
**Priority**: CRITICAL - Core functionality issues

---

## Issues Identified

### 1. ❌ Visual Flow Not Centered
**Issue**: Workflow nodes at top (Source → Staging → Output → FCP) not centered
**Location**: Top toolbar
**Impact**: UI polish
**Priority**: Medium
**Files**: `Views/CompactWorkflowView.swift`

### 2. ❌ Trim Markers Not Consolidated with Playhead
**Issue**:
- Trim markers need to be triangles pointing inward
- Should be on same line as playhead
- Playback should auto-limit to in/out points
**Location**: Player view trim controls
**Impact**: CRITICAL - Core playback functionality
**Priority**: HIGH
**Files**: `Views/PlayerView.swift` or `Views/RowSubviews/PlayerView.swift`

### 3. ❌ Missing Hotkeys
**Issue**: No keyboard shortcuts for navigation/editing
**Required Hotkeys**:
- Left/Right: Navigate videos in filmstrip (Up/Down in vertical view)
- Spacebar: Play/Pause
- Z: Set in point at current playhead position
- X: Set out point at current playhead position
- C: Mark for deletion
**Configuration**: All hotkeys configurable in preferences
**Impact**: CRITICAL - Workflow efficiency
**Priority**: HIGH
**Files**: `VideoCullingApp.swift`, `Views/ContentView.swift`, `Views/PreferencesView.swift`

### 4. ❌ Play Button Not Working Correctly
**Issue**: Video plays a few frames then skips randomly instead of smooth playback from in to out
**Location**: Primary video player
**Impact**: CRITICAL - Playback broken
**Priority**: CRITICAL
**Files**: `Views/PlayerView.swift` or `Views/RowSubviews/PlayerView.swift`

### 5. ❌ LUT Not Applying During Playback
**Issue**:
- LUT applies to paused first frame
- LUT does NOT apply during video playback
**Location**: Video player rendering
**Impact**: CRITICAL - LUT preview not functional
**Priority**: CRITICAL
**Files**: `Views/PlayerView.swift`, `Services/LUTManager.swift`

### 6. ❌ LUT Auto-Learning Not Applying to Other Videos
**Issue**:
- Learning system updates dropdown for other videos
- Preview image does NOT show LUT applied
- Playback does NOT show LUT applied
**Location**: LUT auto-mapping and preview rendering
**Impact**: CRITICAL - LUT workflow broken
**Priority**: CRITICAL
**Files**: `Services/LUTAutoMapper.swift`, `Services/LUTManager.swift`, `Views/PlayerView.swift`

---

## Implementation Order (By Priority)

### Phase 1: Critical Playback Fixes (BLOCKING)
1. **Fix #4**: Play button erratic behavior
2. **Fix #5**: LUT application during playback
3. **Fix #2**: Trim marker consolidation and playback limiting

### Phase 2: Critical Workflow Fixes
4. **Fix #6**: LUT auto-learning application to previews/playback
5. **Fix #3**: Hotkey implementation

### Phase 3: UI Polish
6. **Fix #1**: Visual flow centering

---

## Detailed Implementation Plan

### Fix #4: Play Button Erratic Behavior

**Root Cause Analysis Needed**:
- Check AVPlayer time observer setup
- Verify playback rate settings
- Check for multiple time observers
- Verify trim bounds handling during playback

**Implementation Steps**:
1. Locate PlayerView.swift playback code
2. Check AVPlayer setup and time observers
3. Fix playback loop/seek issues
4. Ensure smooth playback from in to out point
5. Add automatic stop at out point

**Test Cases**:
- Test continuous playback from in to out
- Test playback doesn't skip frames
- Test automatic stop at out point
- Test play/pause toggle

**Files to Modify**:
- `Views/PlayerView.swift` or `Views/RowSubviews/PlayerView.swift`

---

### Fix #5: LUT Application During Playback

**Root Cause Analysis**:
- LUT applies to still frame via CIImage
- Playback likely uses different rendering path
- Need to apply LUT to AVPlayerLayer or video composition

**Implementation Steps**:
1. Check current LUT application method
2. Create AVVideoComposition with CIFilter for LUT
3. Apply video composition to AVPlayer
4. Ensure LUT updates when dropdown changes
5. Test real-time LUT application during playback

**Test Cases**:
- Test LUT applies to paused frame
- Test LUT applies during playback
- Test LUT changes reflect immediately during playback
- Test LUT persists across play/pause

**Files to Modify**:
- `Views/PlayerView.swift`
- `Services/LUTManager.swift` (if needed)

---

### Fix #2: Trim Marker Consolidation

**Current State**:
- Trim markers exist but not consolidated
- Playback not limited to trim range

**Implementation Steps**:
1. Update trim marker UI to triangles (▶ ◀)
2. Position markers on same line as playhead
3. Implement playback limiting:
   - Set AVPlayer to start at trim in
   - Add time observer to stop at trim out
   - Loop or stop at trim out point
4. Update trim slider behavior

**Test Cases**:
- Test trim markers display as triangles
- Test trim markers on same line as playhead
- Test playback starts at in point
- Test playback stops at out point
- Test playback doesn't go beyond out point

**Files to Modify**:
- `Views/PlayerView.swift` or `Views/RowSubviews/PlayerView.swift`

---

### Fix #6: LUT Auto-Learning Application

**Current State**:
- Learning updates dropdown ✅
- Learning does NOT update preview ❌
- Learning does NOT update playback ❌

**Root Cause**:
- Preview image generation doesn't check for auto-applied LUT
- Video composition not created with auto-applied LUT

**Implementation Steps**:
1. When LUT auto-applied, trigger preview regeneration
2. Ensure preview generation uses selectedLUTId from Core Data
3. Ensure video composition uses selectedLUTId
4. Add observer for LUT changes to update preview
5. Test cascade effect when learning new LUT

**Test Cases**:
- Test learning LUT for camera metadata
- Test other videos with same metadata update dropdown
- Test other videos with same metadata update preview
- Test other videos with same metadata update playback
- Test preview reflects LUT immediately

**Files to Modify**:
- `Services/LUTAutoMapper.swift`
- `Views/PlayerView.swift`
- `ViewModels/ContentViewModel.swift`

---

### Fix #3: Hotkey Implementation

**Implementation Steps**:
1. Create HotkeyManager or add to ContentViewModel
2. Implement NSEvent monitor for key presses
3. Map hotkeys to actions:
   - Left/Right: `selectPreviousVideo()` / `selectNextVideo()`
   - Spacebar: `togglePlayPause()`
   - Z: `setTrimInPoint()`
   - X: `setTrimOutPoint()`
   - C: `toggleDeletionFlag()`
4. Add hotkey configuration to PreferencesView
5. Store hotkey preferences in UserDefaults
6. Handle vertical vs horizontal filmstrip orientation

**Test Cases**:
- Test Left/Right navigation
- Test Up/Down navigation (vertical mode)
- Test Spacebar play/pause
- Test Z sets in point
- Test X sets out point
- Test C marks for deletion
- Test hotkey configuration in preferences
- Test hotkeys work with focus on different views

**Files to Modify**:
- `VideoCullingApp.swift` (global event monitor)
- `ViewModels/ContentViewModel.swift` (actions)
- `Views/ContentView.swift` (event handling)
- `Views/PreferencesView.swift` (configuration)
- `Models/UserPreferences.swift` (storage)

---

### Fix #1: Visual Flow Centering

**Implementation Steps**:
1. Locate CompactWorkflowView.swift
2. Add Spacer() before and after workflow nodes
3. Ensure proper centering with .frame(maxWidth: .infinity)
4. Test on different window sizes

**Test Cases**:
- Test workflow nodes centered on load
- Test workflow nodes stay centered on resize
- Test spacing consistent

**Files to Modify**:
- `Views/CompactWorkflowView.swift`

---

## Testing Strategy

### Unit Tests (Per Fix)
- Test each fix individually
- Verify expected behavior
- Test edge cases

### Integration Tests
- Test fixes work together
- Test hotkeys with playback
- Test LUT with trim markers

### UI Tests (Automated)
- Update existing UI tests
- Add new tests for:
  - Hotkey functionality
  - Playback limiting
  - LUT application verification
  - Trim marker positioning

### Manual Testing
- Play videos and verify smooth playback
- Test LUT application visually during playback
- Test trim markers limit playback
- Test hotkeys for workflow

### 5x Randomized Test Cycles
- Run all tests in randomized order
- 5 complete cycles
- Fix any failures immediately
- Continue until 5 clean passes

---

## Success Criteria

### Fix #4: Playback
- ✅ Video plays smoothly from in to out
- ✅ No frame skipping or erratic behavior
- ✅ Automatic stop at out point
- ✅ Automated test validates smooth playback

### Fix #5: LUT Playback
- ✅ LUT applies to paused frame
- ✅ LUT applies during playback
- ✅ LUT changes reflect immediately
- ✅ Automated test validates LUT during playback

### Fix #2: Trim Markers
- ✅ Markers are triangles (▶ ◀)
- ✅ Markers on same line as playhead
- ✅ Playback limited to trim range
- ✅ Automated test validates playback limiting

### Fix #6: LUT Auto-Learning
- ✅ Learning updates dropdown
- ✅ Learning updates preview image
- ✅ Learning updates playback
- ✅ Automated test validates cascade effect

### Fix #3: Hotkeys
- ✅ All hotkeys functional
- ✅ Hotkeys configurable in preferences
- ✅ Hotkeys work in both orientations
- ✅ Automated test validates hotkey actions

### Fix #1: Centering
- ✅ Workflow nodes centered
- ✅ Centering persists on resize
- ✅ Automated test validates centering

### Overall
- ✅ All 6 fixes implemented
- ✅ All tests passing
- ✅ 5x randomized test cycles complete with 0 failures
- ✅ Manual verification complete

---

## Timeline

**Estimated Duration**: 6-8 hours
- Phase 1 (Critical): 3-4 hours
- Phase 2 (Workflow): 2-3 hours
- Phase 3 (Polish): 30 minutes
- Testing (5x cycles): 2 hours

---

## Notes

- Stop at any failure during testing
- Fix immediately before proceeding
- Document all changes
- Update test cases as needed
- Ensure backwards compatibility with existing functionality

---

## Current Status

**Phase**: Phase 3 (Hotkey Implementation)
**Completed Fixes**:
- ✅ Fix #4: Play button erratic behavior (PlayerView.swift)
- ✅ Fix #5: LUT application during playback (PlayerView.swift, LUTManager.swift)
- ✅ Fix #6: LUT auto-learning cascading (LUTAutoMapper.swift, PlayerView.swift)
- ✅ Fix #2: Trim marker consolidation (PlayerView.swift)
- ✅ Fix #1: Visual flow centering (CompactWorkflowView.swift)
- 🔄 Fix #3: Hotkey system (IN PROGRESS)

**Tests Passing**: 60/60 (from previous validation - needs update with new fix tests)
**Next Action**: Complete hotkey integration, build, create tests for all 6 fixes, run 5x validation
