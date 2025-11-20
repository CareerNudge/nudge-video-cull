# Test Updates for New Workflow UI

## Overview

All test scripts and utilities have been updated to work with the new visual workflow interface.

## Changes Made

### 1. UILayoutTests.swift Updates

#### Updated Welcome Screen Handling

**Old behavior:**
- Looked for "Start Import" and "Cull in Place" buttons
- Clicked specific workflow mode button

**New behavior:**
- Looks for single "GO!" button
- Handles smart workflow detection
- Detects and responds to "Cull in Place Warning" dialog if it appears
- Updated text matching: "Ready to begin" OR "Ready to start"

```swift
private func dismissWelcomeScreenIfPresent() {
    // Wait for "Ready to begin" or "Ready to start"
    // Click "GO!" button
    // Handle warning dialog if culling in place is detected
}
```

#### New Test: testWelcomeScreenLayout()

Tests the updated welcome screen:
- ✅ Visual workflow nodes (Source, Output)
- ✅ Single "GO!" button
- ✅ Proper element bounds and visibility

#### New Test: testCompactWorkflowViewLayout()

Tests the compact workflow view in main content:
- ✅ Workflow nodes (Source, Output, FCP)
- ✅ Flow arrows (chevrons)
- ✅ File count and space statistics
- ✅ "Process Import/Culling Job" button

#### Updated Test: testMainContentViewLayout()

Now checks for:
- Visual workflow nodes in toolbar
- "Process Import/Culling Job" button
- File/space statistics labels

### 2. Test Script Compatibility

All existing test scripts remain compatible:
- `run_layout_tests_5x.sh` - Works with new welcome screen flow
- `run_single_layout_test.sh` - Updated for GO! button
- `run_ui_tests_20x.sh` - Compatible with new workflow

### 3. What Tests Now Verify

#### Welcome Screen Tests ✅
- Single "GO!" button exists and is clickable
- Visual workflow diagram shows Source and Output nodes
- Scanning progress indicator at bottom
- Smart detection of cull-in-place scenario

#### Main Content Tests ✅
- Compact workflow view in toolbar
- Source, Output, and FCP nodes visible
- File counts displayed (Files: X)
- Space usage displayed (Space: X GB)
- Process button exists and labeled correctly
- Flow arrows between nodes

#### Layout Tests ✅
- All text elements within bounds
- All buttons properly sized (>20px wide)
- No element clipping
- Statistics labels readable

## Running Updated Tests

### Single Test Run
```bash
./run_single_layout_test.sh
```

### 5x Iteration Run
```bash
./run_layout_tests_5x.sh
```

### Full UI Test Suite (20x)
```bash
./run_ui_tests_20x.sh
```

## Expected Test Behavior

1. **App Launch**: Welcome screen appears automatically
2. **Folder Selection**: Test environment variables configure paths
3. **Scanning**: Background scanning starts after source selection
4. **Ready State**: Wait for "Ready to begin" or "Ready to start"
5. **GO! Button**: Click to proceed
6. **Warning Detection**: If output is empty/same as source, handle warning dialog
7. **Main View**: Verify compact workflow nodes and statistics
8. **Gallery**: Continue with gallery and video row tests

## Smart Detection Scenarios

### Scenario 1: Valid Import Workflow
- Source: `/Volumes/X10 Pro/CLIP`
- Output: `/Volumes/X10 Pro/testoutput` (different, non-empty)
- **Result**: GO! proceeds directly to import mode

### Scenario 2: Cull in Place Detection
- Source: `/Volumes/X10 Pro/CLIP`
- Output: Empty or same as source
- **Result**: Warning dialog appears, test clicks "Proceed with Culling in Place"

## Test Assertions

### Welcome Screen
```swift
XCTAssertTrue(goButton.exists, "GO! button should exist")
XCTAssertTrue(sourceNode.exists, "Source node should be visible")
XCTAssertTrue(outputNode.exists, "Output node should be visible")
```

### Main Content
```swift
XCTAssertTrue(processButton.exists, "Process button should exist")
XCTAssertGreaterThan(statsLabels.count, 0, "Statistics should be displayed")
```

### Layout Verification
```swift
verifyElementWithinBounds(element, context: "...")
XCTAssertGreaterThan(frame.width, 0, "Element should have width")
XCTAssertTrue(element.isHittable, "Element should be clickable")
```

## Debugging Failed Tests

### If GO! button not found:
1. Check welcome screen is fully loaded
2. Verify "Ready to begin" text appears
3. Ensure scanning completed
4. Check button predicate: `label CONTAINS[c] 'GO!'`

### If workflow nodes not visible:
1. Verify CompactWorkflowView.swift is compiled
2. Check target membership includes VideoCullingApp
3. Ensure folders are configured in environment variables
4. Check console for layout errors

### If warning dialog hangs tests:
1. Verify output folder path in environment
2. Check dialog predicate: `title CONTAINS[c] 'Warning'`
3. Ensure "Proceed" button exists in dialog
4. Add debug prints to track dialog state

## Continuous Integration

Tests are designed to run in CI environments:
- ✅ No manual interaction required
- ✅ Environment variable configuration
- ✅ Automatic dialog handling
- ✅ Timeout protection (30 second max wait)
- ✅ Cleanup between test runs

### 4. New LUT Application Tests

#### testLUTApplicationAndAutoApply()

Tests the complete LUT workflow:

**Step 1: LUT Selection**
- Finds LUT picker dropdowns
- Selects a LUT from available options
- Verifies LUT selection was applied

**Step 2: Bake-in Checkbox**
- Locates "Bake in LUT" checkbox
- Enables bake-in if not already enabled
- Verifies checkbox bounds and visibility

**Step 3: Auto-Apply Verification**
- Checks for gamma/color space metadata labels
- Counts matching LUT selections across videos
- Verifies auto-mapping worked (multiple videos with same LUT)

```swift
// Example auto-apply verification
for i in 0..<min(allLUTPickers.count, 5) {
    let picker = allLUTPickers.element(boundBy: i)
    if pickerValue == firstLUTValue && !pickerValue.isEmpty {
        matchingLUTs += 1  // Auto-apply detected
    }
}
```

#### testLUTMetadataDisplay()

Tests camera metadata display that drives LUT auto-mapping:

**Metadata Fields Tested:**
- ✅ Gamma (S-Log, S-Log2, S-Log3)
- ✅ Color Space (S-Gamut, S-Gamut3.Cine)
- ✅ Camera Model (Sony, etc.)

**Verifications:**
- Metadata labels are visible and within bounds
- LUT names are displayed (.cube files, Rec709, etc.)
- Labels are properly formatted and readable

## Future Test Additions

Consider adding tests for:
- [x] LUT application and selection
- [x] Auto-apply to matching gamma/color space
- [x] Metadata display for LUT decisions
- [ ] Cleanup button functionality (post-processing)
- [ ] Node click interactions (folder selection)
- [ ] Statistics accuracy (file count matching)
- [ ] Staging node visibility (external media detection)
- [ ] FCPXML toggle state persistence
- [ ] Warning dialog "Add Different Destination" flow
- [ ] LUT preview in player view
- [ ] User LUT learning system verification

## Summary

All tests have been updated to:
1. ✅ Work with single "GO!" button
2. ✅ Handle smart workflow detection
3. ✅ Verify visual workflow nodes
4. ✅ Check file/space statistics
5. ✅ Test new Process button
6. ✅ Validate warning dialogs

The test suite is now fully compatible with the redesigned workflow UI.
