# Automated Testing Instructions

## Overview

I've created comprehensive test suites for the VideoCullingApp:

- **Unit Tests**: `Tests/LUTAutoMapperTests.swift` (15 tests)
- **UI Tests**: `Tests/VideoCullingAppUITests.swift` (13 tests)
- **Test Runner**: `run_tests_20x.sh` (automated 20x iteration runner)

## Required Manual Setup (5 minutes)

Unfortunately, Xcode test targets cannot be added via command line. You must add them manually:

### Step 1: Add Unit Test Target

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Click on the **VideoCullingApp** project (blue icon at top of navigator)
3. At the bottom left, click the **"+"** button under **TARGETS**
4. Select **"Unit Testing Bundle"** → Next
5. Product Name: **VideoCullingAppTests**
6. Language: **Swift**
7. Click **Finish**

### Step 2: Add UI Test Target

1. Click the **"+"** button again under **TARGETS**
2. Select **"UI Testing Bundle"** → Next
3. Product Name: **VideoCullingAppUITests**
4. Language: **Swift**
5. Click **Finish**

### Step 3: Add Test Files to Targets

#### For LUTAutoMapperTests.swift:

1. In Xcode's Project Navigator, find `Tests/LUTAutoMapperTests.swift`
   - If not visible: Right-click project root → **Add Files to "VideoCullingApp"**
   - Navigate to `Tests/LUTAutoMapperTests.swift` → **Add**

2. Select the file in Project Navigator
3. In the **File Inspector** (right panel), under **Target Membership**:
   - ✓ Check **VideoCullingAppTests**
   - ✓ Check **VideoCullingApp** (needed for `@testable import`)

#### For VideoCullingAppUITests.swift:

1. Find `Tests/VideoCullingAppUITests.swift` in Project Navigator
   - If not visible: Add it the same way as above

2. Select the file in Project Navigator
3. In the **File Inspector**, under **Target Membership**:
   - ✓ Check **VideoCullingAppUITests**
   - ✓ Check **VideoCullingApp**

### Step 4: Add Accessibility Identifiers to UI Elements

For UI tests to work, certain UI elements need accessibility identifiers. Add these to the relevant views:

#### In Views/GalleryView.swift or Views/ContentView.swift:

Find the gallery mode toggle button and add:
```swift
.accessibilityIdentifier("galleryModeButton")
```

You may need to add similar identifiers for other interactive elements the UI tests reference.

### Step 5: Verify Setup

In Xcode:
1. Press **Cmd+U** to run all tests
2. Verify tests can compile and run
3. Fix any compilation errors or missing identifiers

## Running Automated Tests

Once manual setup is complete, run the automated test suite:

```bash
cd /Users/romanwilson/projects/videocull/VideoCullingApp
./run_tests_20x.sh
```

This will:
1. Run all unit tests 20 times consecutively
2. Stop and report if any failures occur
3. If all unit tests pass, proceed to UI tests
4. Run all UI tests 20 times consecutively
5. Stop and report if any failures occur
6. Generate comprehensive test report

## Test Reports

Results are saved to `TestResults/` directory:
- Individual test logs: `*_test_run_*.log`
- Summary report: `test_report_*.txt`

## What the Tests Cover

### Unit Tests (LUTAutoMapperTests.swift)

1. **String Normalization**:
   - Removes hyphens from "s-log3-cine" → "slog3cine"
   - Removes dots from "s.log3.cine" → "slog3cine"
   - Removes spaces from "s log3 cine" → "slog3cine"
   - Handles mixed separators

2. **LUT Matching**:
   - S-Log3 / S-Gamut3.Cine → correct LUT
   - S-Log2 / S-Gamut → correct LUT
   - Apple Log → correct LUT
   - Unknown profiles → nil (no match)

3. **Edge Cases**:
   - Nil gamma → nil result
   - Nil colorSpace → nil result
   - Case insensitivity (lowercase, uppercase, mixed)

4. **Performance**:
   - Normalization speed benchmark
   - LUT matching speed benchmark

### UI Tests (VideoCullingAppUITests.swift)

1. **Gallery Mode Toggle** (2 tests):
   - Toggle between horizontal and vertical modes
   - Rapid toggling doesn't cause crashes (EXC_BAD_ACCESS fix verification)

2. **LUT Auto-Mapping** (2 tests):
   - Selecting LUT applies to matching videos
   - LUT preview updates when selection changes

3. **Trim and Play** (2 tests):
   - Set trim points and play without crashes
   - Playback position stays within trim bounds (bounds checking fix)

4. **Scrubbing Preview** (1 test):
   - Dragging trim handles shows frame preview
   - No crashes during rapid scrubbing

5. **Video Selection** (2 tests):
   - Filmstrip thumbnail selection switches video
   - Table row selection switches video

6. **Performance** (2 tests):
   - Gallery toggle performance
   - Video switching performance

## Troubleshooting

### "Testing target not found"
- You haven't added test targets in Xcode yet (see Step 1-2 above)

### "Could not find test class"
- Test files not added to test targets (see Step 3 above)

### UI tests fail to find elements
- Missing accessibility identifiers (see Step 4 above)
- App may need to be launched with test data

### Tests compile but crash immediately
- Check that test targets have `VideoCullingApp` as dependency
- Verify test targets link against the main app target

## Next Steps

After completing manual setup:

1. Run `./run_tests_20x.sh` to execute automated test suite
2. Review test results in `TestResults/` directory
3. Fix any failures and re-run until all tests pass 20 times
4. Check final report for comprehensive summary

## Test Files Location

- Unit tests: `/Users/romanwilson/projects/videocull/VideoCullingApp/Tests/LUTAutoMapperTests.swift`
- UI tests: `/Users/romanwilson/projects/videocull/VideoCullingApp/Tests/VideoCullingAppUITests.swift`
- Test runner: `/Users/romanwilson/projects/videocull/VideoCullingApp/run_tests_20x.sh`
- Setup guide: `/Users/romanwilson/projects/videocull/VideoCullingApp/XCODE_TEST_SETUP.md`
- This guide: `/Users/romanwilson/projects/videocull/VideoCullingApp/TESTING_INSTRUCTIONS.md`
