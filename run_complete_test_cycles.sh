#!/bin/bash

# Complete Test Cycle Runner
# Runs all UI and layout tests 5 times, validating recent fixes

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
echo "  Complete Test Cycle Runner (5x)"
echo "  Testing All Recent UI Fixes"
echo "==========================================="
echo ""
echo "Source: $SOURCE_PATH"
echo "Output: $OUTPUT_PATH"
echo ""

# Track results
TOTAL_CYCLES=5
SUCCESSFUL_CYCLES=0
FAILED_CYCLES=0

# Test results array
declare -a CYCLE_RESULTS

for cycle in {1..5}; do
    echo ""
    echo "=========================================="
    echo " TEST CYCLE $cycle/$TOTAL_CYCLES"
    echo "=========================================="
    echo ""

    # Clean up test output folder
    echo -e "${BLUE}[Preparing test environment...]${NC}"
    if [ -d "$OUTPUT_PATH" ]; then
        rm -rf "$OUTPUT_PATH"/*
        echo "✓ Cleaned output folder"
    fi

    # Create fresh symlinks for test data
    if [ -d "$SOURCE_PATH" ]; then
        # Count files in source
        FILE_COUNT=$(find "$SOURCE_PATH" -type f \( -iname "*.mov" -o -iname "*.mp4" \) | wc -l | tr -d ' ')
        echo "✓ Test data ready ($FILE_COUNT video files)"
    else
        echo -e "${RED}✗ Source path not found: $SOURCE_PATH${NC}"
        FAILED_CYCLES=$((FAILED_CYCLES + 1))
        CYCLE_RESULTS[$cycle]="FAILED (source not found)"
        continue
    fi

    # Run UILayoutTests
    echo ""
    echo -e "${YELLOW}[Running UI Layout Tests - Cycle $cycle]${NC}"
    LAYOUT_LOG="test_results/cycle_${cycle}_layout.log"
    mkdir -p test_results

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppUITests/UILayoutTests \
        TEST_MODE=true \
        TEST_INPUT_PATH="$SOURCE_PATH" \
        TEST_OUTPUT_PATH="$OUTPUT_PATH" \
        > "$LAYOUT_LOG" 2>&1

    LAYOUT_RESULT=$?

    if [ $LAYOUT_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ Layout tests passed${NC}"
        LAYOUT_STATUS="PASS"
    else
        echo -e "${RED}✗ Layout tests failed${NC}"
        LAYOUT_STATUS="FAIL"
        echo "  See log: $LAYOUT_LOG"
    fi

    # Run VideoCullingAppUITests
    echo ""
    echo -e "${YELLOW}[Running App UI Tests - Cycle $cycle]${NC}"
    APP_LOG="test_results/cycle_${cycle}_app.log"

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppUITests/VideoCullingAppUITests \
        TEST_MODE=true \
        TEST_INPUT_PATH="$SOURCE_PATH" \
        TEST_OUTPUT_PATH="$OUTPUT_PATH" \
        > "$APP_LOG" 2>&1

    APP_RESULT=$?

    if [ $APP_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ App UI tests passed${NC}"
        APP_STATUS="PASS"
    else
        echo -e "${RED}✗ App UI tests failed${NC}"
        APP_STATUS="FAIL"
        echo "  See log: $APP_LOG"
    fi

    # Determine overall cycle result
    if [ $LAYOUT_RESULT -eq 0 ] && [ $APP_RESULT -eq 0 ]; then
        echo ""
        echo -e "${GREEN}=========================================="
        echo "  CYCLE $cycle: ✓ ALL TESTS PASSED"
        echo "==========================================${NC}"
        SUCCESSFUL_CYCLES=$((SUCCESSFUL_CYCLES + 1))
        CYCLE_RESULTS[$cycle]="PASSED"
    else
        echo ""
        echo -e "${RED}=========================================="
        echo "  CYCLE $cycle: ✗ SOME TESTS FAILED"
        echo "==========================================${NC}"
        FAILED_CYCLES=$((FAILED_CYCLES + 1))
        CYCLE_RESULTS[$cycle]="FAILED (Layout: $LAYOUT_STATUS, App: $APP_STATUS)"
    fi

    # Brief pause between cycles
    sleep 2
done

# Final summary
echo ""
echo ""
echo "==========================================="
echo "  FINAL TEST SUMMARY"
echo "==========================================="
echo ""
echo "Total Cycles: $TOTAL_CYCLES"
echo -e "${GREEN}Successful: $SUCCESSFUL_CYCLES${NC}"
echo -e "${RED}Failed: $FAILED_CYCLES${NC}"
echo ""
echo "Cycle-by-Cycle Results:"
for i in {1..5}; do
    STATUS="${CYCLE_RESULTS[$i]}"
    if [[ "$STATUS" == "PASSED" ]]; then
        echo -e "  Cycle $i: ${GREEN}$STATUS${NC}"
    else
        echo -e "  Cycle $i: ${RED}$STATUS${NC}"
    fi
done
echo ""

# Exit with success only if all 5 cycles passed
if [ $SUCCESSFUL_CYCLES -eq $TOTAL_CYCLES ]; then
    echo -e "${GREEN}=========================================="
    echo "  ✓ ALL 5 CYCLES PASSED!"
    echo "==========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}=========================================="
    echo "  ⚠ $FAILED_CYCLES/$TOTAL_CYCLES CYCLES FAILED"
    echo "==========================================${NC}"
    echo ""
    echo "Review logs in test_results/ folder for details"
    exit 1
fi
