#!/bin/bash

# Automated UI Test Runner with Real Test Data
set -e

# User-specified paths
SOURCE_DATA="/Users/romanwilson/projects/videocull/VideoCullingApp/testclips"
TEST_OUTPUT="/Users/romanwilson/projects/videocull/VideoCullingApp/testoutput"

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

# Create output directory and results directory
mkdir -p "$TEST_OUTPUT"
mkdir -p "$RESULTS_DIR"

FAILURES=0
TOTAL_RUNS=0

# No setup_test_data function needed as we use paths directly

cleanup_test_data() {
    echo -e "${BLUE}Cleaning up test data...${NC}"

    # Clean up any processed files in output folder
    rm -rf "${TEST_OUTPUT}/*" 2>/dev/null || true # Ignore errors if folder is empty

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
    # Pass the actual source and output paths to the app
    export TEST_INPUT_PATH="$SOURCE_DATA"
    export TEST_OUTPUT_PATH="$TEST_OUTPUT"

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppUITests \
        > "$RESULTS_DIR/ui_test_run_${iteration}_${TIMESTAMP}.log" 2>&1

    # Check if tests actually passed by looking for TEST FAILED in output
    if grep -q "** TEST FAILED **" "$RESULTS_DIR/ui_test_run_${iteration}_${TIMESTAMP}.log"; then
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

    # No setup_test_data call needed here

    # Run UI tests
    if ! run_ui_tests $i; then
        FAILURES=$((FAILURES + 1))
        cleanup_test_data # Clean up on failure
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
echo "Test data used: All files in $SOURCE_DATA"
echo "All logs saved to: $RESULTS_DIR/"
