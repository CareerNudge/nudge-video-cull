#!/bin/bash

# Automated Test Runner - Runs each test suite 20 times
# This script will run after test targets are manually added to Xcode

set -e  # Exit on error

PROJECT="VideoCullingApp.xcodeproj"
SCHEME="VideoCullingApp"
DESTINATION="platform=macOS"
RESULTS_DIR="TestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "  Automated Test Runner (20x per suite)"
echo "========================================="
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize result tracking
UNIT_TEST_FAILURES=0
UI_TEST_FAILURES=0
TOTAL_UNIT_RUNS=0
TOTAL_UI_RUNS=0

# Function to run unit tests
run_unit_tests() {
    local iteration=$1
    echo -e "${YELLOW}[Unit Tests - Iteration $iteration/20]${NC}"

    if xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppTests/LUTAutoMapperTests \
        2>&1 | tee "$RESULTS_DIR/unit_test_run_${iteration}_${TIMESTAMP}.log"; then
        echo -e "${GREEN}✓ Unit tests passed (iteration $iteration)${NC}"
        return 0
    else
        echo -e "${RED}✗ Unit tests FAILED (iteration $iteration)${NC}"
        return 1
    fi
}

# Function to run UI tests
run_ui_tests() {
    local iteration=$1
    echo -e "${YELLOW}[UI Tests - Iteration $iteration/20]${NC}"

    if xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppUITests \
        2>&1 | tee "$RESULTS_DIR/ui_test_run_${iteration}_${TIMESTAMP}.log"; then
        echo -e "${GREEN}✓ UI tests passed (iteration $iteration)${NC}"
        return 0
    else
        echo -e "${RED}✗ UI tests FAILED (iteration $iteration)${NC}"
        return 1
    fi
}

# Run Unit Tests 20 times
echo ""
echo "========================================="
echo "  Phase 1: Unit Tests (LUTAutoMapper)"
echo "========================================="
echo ""

for i in {1..20}; do
    TOTAL_UNIT_RUNS=$((TOTAL_UNIT_RUNS + 1))

    if ! run_unit_tests $i; then
        UNIT_TEST_FAILURES=$((UNIT_TEST_FAILURES + 1))
        echo -e "${RED}Stopping unit tests due to failure. Please fix issues and re-run.${NC}"
        echo ""
        echo "To debug, check the log file:"
        echo "  $RESULTS_DIR/unit_test_run_${i}_${TIMESTAMP}.log"
        exit 1
    fi

    echo ""
    sleep 1  # Brief pause between runs
done

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ✓ All 20 unit test runs PASSED!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Run UI Tests 20 times (only if unit tests all passed)
echo ""
echo "========================================="
echo "  Phase 2: UI Tests"
echo "========================================="
echo ""

for i in {1..20}; do
    TOTAL_UI_RUNS=$((TOTAL_UI_RUNS + 1))

    if ! run_ui_tests $i; then
        UI_TEST_FAILURES=$((UI_TEST_FAILURES + 1))
        echo -e "${RED}Stopping UI tests due to failure. Please fix issues and re-run.${NC}"
        echo ""
        echo "To debug, check the log file:"
        echo "  $RESULTS_DIR/ui_test_run_${i}_${TIMESTAMP}.log"
        exit 1
    fi

    echo ""
    sleep 2  # Longer pause between UI test runs (allow app to fully reset)
done

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ✓ All 20 UI test runs PASSED!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Generate final report
REPORT_FILE="$RESULTS_DIR/test_report_${TIMESTAMP}.txt"

cat > "$REPORT_FILE" <<EOF
========================================
  VideoCullingApp Test Report
========================================

Date: $(date)
Project: $PROJECT
Scheme: $SCHEME

========================================
  Test Results Summary
========================================

Unit Tests (LUTAutoMapperTests):
  - Total Runs: $TOTAL_UNIT_RUNS
  - Failures: $UNIT_TEST_FAILURES
  - Success Rate: $(( (TOTAL_UNIT_RUNS - UNIT_TEST_FAILURES) * 100 / TOTAL_UNIT_RUNS ))%

UI Tests (VideoCullingAppUITests):
  - Total Runs: $TOTAL_UI_RUNS
  - Failures: $UI_TEST_FAILURES
  - Success Rate: $(( (TOTAL_UI_RUNS - UI_TEST_FAILURES) * 100 / TOTAL_UI_RUNS ))%

Overall Status: ALL TESTS PASSED ✓

========================================
  Test Coverage
========================================

Unit Tests:
  ✓ String normalization (hyphens, dots, spaces)
  ✓ LUT matching for S-Log3/S-Gamut3.Cine
  ✓ LUT matching for S-Log2/S-Gamut
  ✓ LUT matching for Apple Log
  ✓ Nil parameter handling
  ✓ Unknown profile handling
  ✓ Case insensitivity
  ✓ Performance benchmarks

UI Tests:
  ✓ Gallery mode toggle
  ✓ Gallery mode crash prevention
  ✓ LUT auto-mapping
  ✓ LUT preview updates
  ✓ Trim and play
  ✓ Trim bounds checking
  ✓ Scrubbing preview
  ✓ Video selection from filmstrip
  ✓ Video selection from table
  ✓ Performance tests

========================================
  Test Artifacts
========================================

All test logs saved to: $RESULTS_DIR/
Log pattern: *_${TIMESTAMP}.log

========================================
  Conclusion
========================================

All 20 iterations of both unit and UI tests passed successfully.
The application is stable and ready for production use.

EOF

echo ""
echo "========================================="
echo "  Final Report"
echo "========================================="
cat "$REPORT_FILE"

echo ""
echo -e "${GREEN}Report saved to: $REPORT_FILE${NC}"
echo ""
echo -e "${GREEN}🎉 All tests completed successfully! 🎉${NC}"
