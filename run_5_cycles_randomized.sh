#!/bin/bash

# Run 5 test cycles with randomized test order each time
# This helps catch test interdependencies and state issues

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
NC='\033[0m'

echo "==========================================="
echo "  Running 5 Cycles with Randomized Order"
echo "==========================================="
echo ""

# All 12 tests
ALL_TESTS=(
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

# Function to shuffle array (Fisher-Yates shuffle)
shuffle_tests() {
    local array=("$@")
    local size=${#array[@]}

    for ((i=size-1; i>0; i--)); do
        local j=$((RANDOM % (i+1)))
        local temp="${array[i]}"
        array[i]="${array[j]}"
        array[j]="$temp"
    done

    echo "${array[@]}"
}

# Function to run a single test
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
        echo "==========================================${NC}"
        echo ""
        echo "Last 30 lines of log:"
        tail -30 "$log_file"
        echo ""
        echo "Full log: $log_file"
        return 1
    fi
}

# Create results directory
mkdir -p test_results_randomized

# Run 5 cycles
for cycle in {1..5}; do
    echo ""
    echo "=========================================="
    echo "  CYCLE $cycle/5"
    echo "=========================================="
    echo ""

    # Shuffle tests for this cycle
    SHUFFLED_TESTS=($(shuffle_tests "${ALL_TESTS[@]}"))

    echo -e "${BLUE}Test order for cycle $cycle:${NC}"
    for i in "${!SHUFFLED_TESTS[@]}"; do
        test_name=$(echo "${SHUFFLED_TESTS[$i]}" | rev | cut -d'/' -f1 | rev)
        echo "  $((i+1)). $test_name"
    done
    echo ""

    PASSED=0
    FAILED=0

    for test_path in "${SHUFFLED_TESTS[@]}"; do
        # Extract test class and test name
        test_class=$(echo "$test_path" | cut -d'/' -f1-2)
        test_name=$(echo "$test_path" | cut -d'/' -f3)

        log_file="test_results_randomized/cycle${cycle}_${test_name}.log"

        if run_single_test "$test_class" "$test_name" "$log_file"; then
            PASSED=$((PASSED + 1))
        else
            FAILED=$((FAILED + 1))
            echo ""
            echo -e "${RED}CYCLE $cycle FAILED - Stopping${NC}"
            echo ""
            echo "Summary: $PASSED passed, $FAILED failed"
            exit 1
        fi

        echo ""
    done

    echo ""
    echo -e "${GREEN}=========================================="
    echo "  ✓ CYCLE $cycle PASSED!"
    echo "  Passed: $PASSED"
    echo "==========================================${NC}"
    echo ""
    sleep 2
done

echo ""
echo "==========================================="
echo "  ✓ ALL 5 CYCLES PASSED!"
echo "  Total Tests Run: 60 (12 tests × 5 cycles)"
echo "==========================================="
