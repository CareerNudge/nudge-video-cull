#!/bin/bash

# Single UI Test Verification
set -e

SOURCE_DATA="/Volumes/X10 Pro/CLIP"
TEST_OUTPUT="/Volumes/X10 Pro/testoutput"
TEST_INPUT="$TEST_OUTPUT/test_input"

echo "==========================================="
echo "  Single UI Test Verification"
echo "==========================================="
echo ""

# Verify source data exists
if [ ! -d "$SOURCE_DATA" ]; then
    echo "ERROR: Source data not found at $SOURCE_DATA"
    exit 1
fi

# Create output and test input directories
mkdir -p "$TEST_OUTPUT"
mkdir -p "$TEST_INPUT"

# Select test files (just 3 videos for quick verification)
TEST_FILES=(
    "20251116_a18610.MP4"
    "20251116_a18610M01.XML"
    "20251116_a18612.MP4"
    "20251116_a18612M01.XML"
    "20251116_a18613.MP4"
    "20251116_a18613M01.XML"
)

echo "Setting up test data (symlinks)..."
# Create symlinks to source files
for file in "${TEST_FILES[@]}"; do
    if [ -f "$SOURCE_DATA/$file" ]; then
        ln -sf "$SOURCE_DATA/$file" "$TEST_INPUT/$file"
        echo "  ✓ Linked: $file"
    fi
done

echo ""
echo "Test data ready. Files in test folder:"
ls -lh "$TEST_INPUT"

echo ""
echo "Ensuring app is not running..."
pkill -9 "VideoCullingApp" || true

echo ""
echo "Running single UI test (testGalleryModeToggle)..."
echo ""

# Set environment variables and run test
export TEST_MODE=1
export TEST_INPUT_PATH="$TEST_INPUT"
export TEST_OUTPUT_PATH="$TEST_OUTPUT"

xcodebuild test \
    -project VideoCullingApp.xcodeproj \
    -scheme VideoCullingApp \
    -destination 'platform=macOS' \
    -only-testing:VideoCullingAppUITests/VideoCullingAppUITests/testGalleryModeToggle \
    2>&1 | tee verification_test.log

# Check if tests actually passed by looking for TEST FAILED in output
if grep -q "\*\* TEST FAILED \*\*" verification_test.log; then
    echo ""
    echo "❌ Test FAILED"
    echo ""
    echo "Check verification_test.log for details"
    exit 1
else
    echo ""
    echo "✅ Test PASSED!"
    echo ""
    echo "System is ready for 20x automated testing."
fi

echo ""
echo "Cleaning up test data..."
rm -rf "$TEST_INPUT"

echo ""
echo "✅ Verification complete!"
