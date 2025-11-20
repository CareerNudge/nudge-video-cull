#!/bin/bash

# Monitored Test Runner
# Runs tests and stops immediately on failure for quick fixing

PROJECT="VideoCullingApp.xcodeproj"
SCHEME="VideoCullingApp"
DESTINATION="platform=macOS"

# Test data paths
SOURCE_PATH="/Volumes/X10 Pro/CLIP"
OUTPUT_PATH="/Volumes/X10 Pro/testoutput"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo "==========================================="
echo "  Monitored Test Runner"
echo "  Stops on first failure for quick fixing"
echo "==========================================="
echo ""

# Function to run a single test and check result immediately
run_single_test() {
    local test_class=$1
    local test_name=$2
    local log_file=$3

    echo -e "${YELLOW}Testing: $test_class.$test_name${NC}"

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:"$test_class/$test_name" \
        TEST_MODE=true \
        TEST_INPUT_PATH="$SOURCE_PATH" \
        TEST_OUTPUT_PATH="$OUTPUT_PATH" \
        > "$log_file" 2>&1

    local result=$?

    if [ $result -eq 0 ]; then
        echo -e "${GREEN}  ✓ PASSED${NC}"
        return 0
    else
        echo -e "${RED}  ✗ FAILED${NC}"
        echo ""
        echo -e "${RED}=========================================="
        echo "  TEST FAILED: $test_name"
        echo -e "==========================================${NC}"
        echo ""
        echo "Last 30 lines of log:"
        tail -30 "$log_file"
        echo ""
        echo "Full log: $log_file"
        return 1
    fi
}

# Create results directory
mkdir -p test_results_monitored

echo "Source: $SOURCE_PATH"
echo "Output: $OUTPUT_PATH"
echo ""

# Test our recent UI fixes first (most important)
echo "=========================================="
echo "  Testing Recent UI Fixes"
echo "=========================================="
echo ""

TESTS_TO_RUN=(
    "VideoCullingAppUITests/UILayoutTests/testFileStatisticsDisplayActualValues"
    "VideoCullingAppUITests/UILayoutTests/testWorkflowNodesCentered"
    "VideoCullingAppUITests/UILayoutTests/testTrimMarkersConsolidatedWithPlayhead"
    "VideoCullingAppUITests/UILayoutTests/testDeletionFlagPersistence"
    "VideoCullingAppUITests/UILayoutTests/testLUTAutoMappingAppliesToPreviews"
    "VideoCullingAppUITests/UILayoutTests/testLUTAutoApplyIndicator"
    "VideoCullingAppUITests/UILayoutTests/testTrimPlaybackConstraints"
    "VideoCullingAppUITests/UILayoutTests/testEnhancedLUTPreviewApplication"
    "VideoCullingAppUITests/VideoCullingAppUITests/testWelcomeScreenWorkflow"
    "VideoCullingAppUITests/VideoCullingAppUITests/testCompactWorkflowNodesDisplay"
    "VideoCullingAppUITests/VideoCullingAppUITests/testFileStatisticsDisplay"
    "VideoCullingAppUITests/VideoCullingAppUITests/testWorkflowNodeCentering"
)

PASSED=0
FAILED=0

for test_path in "${TESTS_TO_RUN[@]}"; do
    # Extract test class and test name
    test_class=$(echo "$test_path" | cut -d'/' -f1-2)
    test_name=$(echo "$test_path" | cut -d'/' -f3)

    log_file="test_results_monitored/${test_name}.log"

    if run_single_test "$test_class" "$test_name" "$log_file"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        echo ""
        echo -e "${RED}Stopping on first failure for immediate fix.${NC}"
        echo ""
        echo "Summary: $PASSED passed, $FAILED failed"
        exit 1
    fi

    echo ""
done

# If we made it here, all tests passed!
echo ""
echo -e "${GREEN}=========================================="
echo "  ✓ ALL TESTS PASSED!"
echo "  Passed: $PASSED"
echo "==========================================${NC}"

exit 0
