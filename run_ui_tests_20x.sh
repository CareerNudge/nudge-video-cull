#!/bin/bash

# Automated UI Test Runner with Real Test Data
set -e

SOURCE_DATA="/Volumes/X10 Pro/CLIP"
TEST_OUTPUT="/Volumes/X10 Pro/testoutput"
TEST_INPUT="$TEST_OUTPUT/test_input"
PROJECT="VideoCullingApp.xcodeproj"
SCHEME="VideoCullingApp"
DESTINATION="platform=macOS"
RESULTS_DIR="TestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo "==========================================="
echo "  UI Tests: 20x Iteration Run"
echo "  Using Real Test Data"
echo "==========================================="
echo ""
echo "Source: $SOURCE_DATA"
echo "Output: $TEST_OUTPUT"
echo ""

# Verify source data exists
if [ ! -d "$SOURCE_DATA" ]; then
    echo -e "${RED}ERROR: Source data not found at $SOURCE_DATA${NC}"
    exit 1
fi

# Create output directory
mkdir -p "$TEST_OUTPUT"
mkdir -p "$RESULTS_DIR"

# Select test files (first 5 videos + XMLs for faster testing)
TEST_FILES=(
    "20251116_a18610.MP4"
    "20251116_a18610M01.XML"
    "20251116_a18612.MP4"
    "20251116_a18612M01.XML"
    "20251116_a18613.MP4"
    "20251116_a18613M01.XML"
    "20251116_a18614.MP4"
    "20251116_a18614M01.XML"
    "20251116_a18615.MP4"
    "20251116_a18615M01.XML"
)

FAILURES=0
TOTAL_RUNS=0

setup_test_data() {
    local run_num=$1
    echo -e "${BLUE}Setting up test data for run $run_num...${NC}"

    # Create fresh test input folder
    rm -rf "$TEST_INPUT"
    mkdir -p "$TEST_INPUT"

    # Create symlinks to source files (fast, no copying)
    for file in "${TEST_FILES[@]}"; do
        if [ -f "$SOURCE_DATA/$file" ]; then
            ln -s "$SOURCE_DATA/$file" "$TEST_INPUT/$file"
        fi
    done

    echo "✓ Test data ready (${#TEST_FILES[@]} files via symlinks)"
}

cleanup_test_data() {
    echo -e "${BLUE}Cleaning up test data...${NC}"

    # Remove test input folder
    rm -rf "$TEST_INPUT"

    # Clean up any processed files in output folder (but keep test input staging area)
    find "$TEST_OUTPUT" -type f -name "*.MP4" -o -name "*.XML" 2>/dev/null | while read file; do
        if [[ "$file" != *"test_input"* ]]; then
            rm -f "$file"
        fi
    done

    echo "✓ Cleanup complete"
}

run_ui_tests() {
    local iteration=$1
    echo -e "${YELLOW}[UI Tests - Run $iteration/20]${NC}"

    # Ensure app is not running
    pkill -9 "VideoCullingApp" || true
    sleep 1

    # Set environment variable for app to detect test mode
    export TEST_MODE=1
    export TEST_INPUT_PATH="$TEST_INPUT"
    export TEST_OUTPUT_PATH="$TEST_OUTPUT"

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppUITests \
        > "$RESULTS_DIR/ui_test_run_${iteration}_${TIMESTAMP}.log" 2>&1

    # Check if tests actually passed by looking for TEST FAILED in output
    if grep -q "\*\* TEST FAILED \*\*" "$RESULTS_DIR/ui_test_run_${iteration}_${TIMESTAMP}.log"; then
        echo -e "${RED}✗ Run $iteration FAILED${NC}"
        echo "Log: $RESULTS_DIR/ui_test_run_${iteration}_${TIMESTAMP}.log"
        return 1
    else
        echo -e "${GREEN}✓ Run $iteration passed${NC}"
        return 0
    fi
}

# Main test loop
for i in {1..20}; do
    TOTAL_RUNS=$((TOTAL_RUNS + 1))

    echo ""
    echo "=========================================="
    echo " Test Iteration $i/20"
    echo "=========================================="

    # Setup test data
    setup_test_data $i

    # Run UI tests
    if ! run_ui_tests $i; then
        FAILURES=$((FAILURES + 1))
        cleanup_test_data
        echo ""
        echo -e "${RED}Stopping due to test failure${NC}"
        exit 1
    fi

    # Cleanup
    cleanup_test_data

    echo ""
    sleep 2
done

# Final summary
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  ✓ All 20 UI test runs PASSED!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Total runs: $TOTAL_RUNS"
echo "Failures: $FAILURES"
echo "Success rate: 100%"
echo ""
echo "Test data used: ${#TEST_FILES[@]} files (5 videos + 5 XMLs)"
echo "All logs saved to: $RESULTS_DIR/"
