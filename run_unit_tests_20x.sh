#!/bin/bash

# Run unit tests 20 times
set -e

PROJECT="VideoCullingApp.xcodeproj"
SCHEME="VideoCullingApp"
DESTINATION="platform=macOS"
RESULTS_DIR="TestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "==========================================="
echo "  Unit Tests: 20x Iteration Run"
echo "==========================================="
echo ""

mkdir -p "$RESULTS_DIR"

FAILURES=0
TOTAL_RUNS=0

for i in {1..20}; do
    TOTAL_RUNS=$((TOTAL_RUNS + 1))
    echo -e "${YELLOW}[Unit Tests - Run $i/20]${NC}"

    if xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:VideoCullingAppTests/LUTAutoMapperTests \
        > "$RESULTS_DIR/unit_test_run_${i}_${TIMESTAMP}.log" 2>&1; then
        echo -e "${GREEN}✓ Run $i passed${NC}"
    else
        FAILURES=$((FAILURES + 1))
        echo -e "${RED}✗ Run $i FAILED${NC}"
        echo ""
        echo "Log file: $RESULTS_DIR/unit_test_run_${i}_${TIMESTAMP}.log"
        exit 1
    fi

    echo ""
    sleep 1
done

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  ✓ All 20 unit test runs PASSED!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Total runs: $TOTAL_RUNS"
echo "Failures: $FAILURES"
echo "Success rate: 100%"
echo ""
echo "All logs saved to: $RESULTS_DIR/"
