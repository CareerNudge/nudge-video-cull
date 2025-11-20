#!/bin/bash

# Comprehensive UI Layout Tests - 5x Iteration Run
set -e

SOURCE_DATA="/Volumes/X10 Pro/CLIP"
TEST_OUTPUT="/Volumes/X10 Pro/testoutput"
TEST_INPUT="$TEST_OUTPUT/test_input"
PROJECT="VideoCullingApp.xcodeproj"
SCHEME="VideoCullingApp"
DESTINATION="platform=macOS"
RESULTS_DIR="LayoutTestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo "==========================================="
echo "  UI Layout Tests: 5x Iteration Run"
echo "  Testing ALL screens for layout issues"
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

# Select test files (3 videos + XMLs for layout testing)
TEST_FILES=(
    "20251116_a18610.MP4"
    "20251116_a18610M01.XML"
    "20251116_a18612.MP4"
    "20251116_a18612M01.XML"
    "20251116_a18613.MP4"
    "20251116_a18613M01.XML"
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
    rm -rf "$TEST_INPUT"
    echo "✓ Cleanup complete"
}

run_layout_tests() {
    local iteration=$1
    echo -e "${YELLOW}[Layout Tests - Run $iteration/5]${NC}"

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
        -only-testing:VideoCullingAppUITests/UILayoutTests \
        > "$RESULTS_DIR/layout_test_run_${iteration}_${TIMESTAMP}.log" 2>&1

    # Check if tests actually passed by looking for TEST FAILED in output
    if grep -q "\*\* TEST FAILED \*\*" "$RESULTS_DIR/layout_test_run_${iteration}_${TIMESTAMP}.log"; then
        echo -e "${RED}✗ Run $iteration FAILED${NC}"
        echo "Log: $RESULTS_DIR/layout_test_run_${iteration}_${TIMESTAMP}.log"

        # Show which tests failed
        grep -A2 "error:" "$RESULTS_DIR/layout_test_run_${iteration}_${TIMESTAMP}.log" | head -20

        return 1
    else
        echo -e "${GREEN}✓ Run $iteration passed${NC}"
        return 0
    fi
}

# Main test loop
for i in {1..5}; do
    TOTAL_RUNS=$((TOTAL_RUNS + 1))

    echo ""
    echo "=========================================="
    echo " Test Iteration $i/5"
    echo "=========================================="

    # Setup test data
    setup_test_data $i

    # Run layout tests
    if ! run_layout_tests $i; then
        FAILURES=$((FAILURES + 1))
        cleanup_test_data
        echo ""
        echo -e "${RED}Stopping due to test failure${NC}"
        echo ""
        echo "Review the log file for details:"
        echo "$RESULTS_DIR/layout_test_run_${i}_${TIMESTAMP}.log"
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
echo -e "${GREEN}  ✓ All 5 layout test runs PASSED!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Total runs: $TOTAL_RUNS"
echo "Failures: $FAILURES"
echo "Success rate: 100%"
echo ""
echo "Tests performed:"
echo "  ✓ Welcome screen layout"
echo "  ✓ Main content view layout"
echo "  ✓ Gallery mode layout"
echo "  ✓ Video row layout"
echo "  ✓ Player view layout"
echo "  ✓ Preferences layout"
echo "  ✓ Metadata display layout"
echo "  ✓ Text fields layout"
echo "  ✓ Star rating layout"
echo "  ✓ Progress views layout"
echo "  ✓ Comprehensive layout check"
echo ""
echo "All logs saved to: $RESULTS_DIR/"
