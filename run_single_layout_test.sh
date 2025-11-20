#!/bin/bash

# Single Layout Test Run - Verification
# Tests the updated UILayoutTests with new welcome screen workflow

set -e

PROJECT="VideoCullingApp.xcodeproj"
SCHEME="VideoCullingApp"
DESTINATION="platform=macOS,arch=x86_64"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="single_layout_test_${TIMESTAMP}.log"

# Test paths
SOURCE_PATH="/Volumes/X10 Pro/CLIP"
OUTPUT_PATH="/Volumes/X10 Pro/testoutput"

echo "==========================================="
echo "  Single Layout Test Run - Verification"
echo "  Testing updated welcome screen workflow"
echo "==========================================="
echo ""
echo "Source: $SOURCE_PATH"
echo "Output: $OUTPUT_PATH"
echo ""

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$OUTPUT_PATH" 2>/dev/null || true
    mkdir -p "$OUTPUT_PATH"

    # Kill any running app instances
    pkill -9 "VideoCullingApp" 2>/dev/null || true
    pkill -9 -f "xcodebuild test" 2>/dev/null || true
    sleep 2
}

# Setup test data
setup_test_data() {
    echo -e "\033[1;34mSetting up test data...\033[0m"

    # Create output directory
    mkdir -p "$OUTPUT_PATH"

    # Create symlinks to real test videos (first 6 files)
    cd "$OUTPUT_PATH"
    count=0
    shopt -s nullglob
    for file in "$SOURCE_PATH"/*.mp4 "$SOURCE_PATH"/*.MP4 "$SOURCE_PATH"/*.mov "$SOURCE_PATH"/*.MOV; do
        if [ -f "$file" ]; then
            ln -sf "$file" .
            ((count++))
            if [ $count -eq 6 ]; then
                break
            fi
        fi
    done
    shopt -u nullglob
    cd - > /dev/null

    echo "✓ Test data ready ($count files via symlinks)"
}

# Run the test
echo -e "\033[1;33m[Running Layout Tests]\033[0m"

# Cleanup before test
cleanup
setup_test_data

# Run the layout tests
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:VideoCullingAppUITests/UILayoutTests \
    TEST_MODE=true \
    TEST_INPUT_PATH="$OUTPUT_PATH" \
    TEST_OUTPUT_PATH="$OUTPUT_PATH" \
    > "$LOG_FILE" 2>&1

# Check result
if [ $? -eq 0 ]; then
    echo -e "\033[0;32m✓ Layout tests PASSED\033[0m"
    echo ""
    echo "Test completed successfully!"
    echo "Log: $LOG_FILE"
else
    echo -e "\033[0;31m✗ Layout tests FAILED\033[0m"
    echo "Log: $LOG_FILE"
    echo ""
    echo "Last 30 lines of log:"
    tail -30 "$LOG_FILE"
    exit 1
fi

# Cleanup after test
cleanup

echo ""
echo "==========================================="
echo "  Verification Complete"
echo "==========================================="
