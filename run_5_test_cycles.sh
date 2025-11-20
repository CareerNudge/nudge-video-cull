#!/bin/bash

# Run monitored tests 5 times to ensure consistency

echo "==========================================="
echo "  Running 5 Complete Test Cycles"
echo "==========================================="
echo ""

for i in {1..5}; do
    echo "=========================================="
    echo "  CYCLE $i/5"
    echo "=========================================="
    echo ""

    ./run_monitored_tests.sh

    if [ $? -ne 0 ]; then
        echo ""
        echo "CYCLE $i FAILED - Stopping"
        exit 1
    fi

    echo ""
    echo "✓ CYCLE $i PASSED"
    echo ""
    sleep 2
done

echo ""
echo "==========================================="
echo "  ✓ ALL 5 CYCLES PASSED!"
echo "==========================================="
