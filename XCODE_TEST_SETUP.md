# Xcode Test Target Setup

## Quick Setup Steps

### 1. Add Unit Test Target

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Click on the project in the navigator (blue icon at top)
3. At the bottom left, click the "+" button under TARGETS
4. Select "Unit Testing Bundle" → Next
5. Product Name: `VideoCullingAppTests`
6. Language: Swift
7. Finish

### 2. Add Test Files to Target

The test file already exists: `Tests/LUTAutoMapperTests.swift`

1. In Xcode, find `Tests/LUTAutoMapperTests.swift` in the file navigator
2. If it's not visible, right-click project root → Add Files to "VideoCullingApp"
3. Navigate to `Tests/LUTAutoMapperTests.swift` → Add
4. In the file inspector (right panel), check the box for `VideoCullingAppTests` target
5. Make sure `VideoCullingApp` target is also checked (for @testable import)

### 3. Add UI Test Target

1. Click "+" button under TARGETS again
2. Select "UI Testing Bundle" → Next
3. Product Name: `VideoCullingAppUITests`
4. Language: Swift
5. Finish

### 4. Configure Test Targets

For both test targets, ensure they have access to the main app:

1. Select test target → Build Phases
2. Verify "Target Dependencies" includes `VideoCullingApp`
3. Verify "Link Binary With Libraries" is properly configured

## Running Tests from Command Line

Once targets are configured:

```bash
# Run all unit tests
xcodebuild test -project VideoCullingApp.xcodeproj -scheme VideoCullingApp -destination 'platform=macOS'

# Run specific test class
xcodebuild test -project VideoCullingApp.xcodeproj -scheme VideoCullingApp -destination 'platform=macOS' -only-testing:VideoCullingAppTests/LUTAutoMapperTests

# Run UI tests
xcodebuild test -project VideoCullingApp.xcodeproj -scheme VideoCullingApp -destination 'platform=macOS' -only-testing:VideoCullingAppUITests
```

## Test Files Created

- ✅ `Tests/LUTAutoMapperTests.swift` - Unit tests for LUT auto-mapping logic (15 tests)
- ⏳ `Tests/VideoCullingAppUITests.swift` - UI tests (to be created)

## After Setup

Once test targets are added in Xcode, the automated test runner will:
1. Run each test suite 20 times
2. Debug and fix any failures
3. Iterate until all tests pass 20 times consecutively
4. Generate final test report
