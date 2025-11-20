#!/bin/bash
# Test script to verify the destination folder selection fix

echo "========================================="
echo "Testing Destination Folder Selection Fix"
echo "========================================="
echo ""

# Get the app PID before test
APP_PID=$(pgrep -x VideoCullingApp)

if [ -z "$APP_PID" ]; then
    echo "❌ App is not running. Please launch it first."
    exit 1
fi

echo "✓ App is running (PID: $APP_PID)"
echo ""

# Monitor for crashes
echo "Monitoring for crashes for 30 seconds..."
echo "Please perform these steps in the app:"
echo "  1. Click on the destination folder button"
echo "  2. Select a folder (or cancel)"
echo "  3. Try this 2-3 times"
echo ""

CRASH_COUNT_BEFORE=$(ls ~/Library/Logs/DiagnosticReports/VideoCullingApp* 2>/dev/null | wc -l)

# Wait for user to test
for i in {30..1}; do
    # Check if app is still running
    if ! ps -p $APP_PID > /dev/null 2>&1; then
        echo ""
        echo "❌ App crashed or was closed!"

        # Check for new crash reports
        CRASH_COUNT_AFTER=$(ls ~/Library/Logs/DiagnosticReports/VideoCullingApp* 2>/dev/null | wc -l)

        if [ $CRASH_COUNT_AFTER -gt $CRASH_COUNT_BEFORE ]; then
            echo ""
            echo "New crash report detected:"
            ls -lt ~/Library/Logs/DiagnosticReports/VideoCullingApp* 2>/dev/null | head -1
            exit 1
        else
            echo "App was closed normally (no crash report)"
            exit 0
        fi
    fi

    echo -ne "\rTime remaining: ${i}s  "
    sleep 1
done

echo ""
echo ""
echo "✅ Test completed successfully!"
echo "✅ App is still running without crashes"
echo ""

# Check final crash count
CRASH_COUNT_AFTER=$(ls ~/Library/Logs/DiagnosticReports/VideoCullingApp* 2>/dev/null | wc -l)

if [ $CRASH_COUNT_AFTER -eq $CRASH_COUNT_BEFORE ]; then
    echo "✅ No new crash reports generated"
    echo ""
    echo "========================================="
    echo "FIX VERIFIED: Destination folder selection is working!"
    echo "========================================="
else
    echo "❌ New crash report detected"
    ls -lt ~/Library/Logs/DiagnosticReports/VideoCullingApp* 2>/dev/null | head -1
fi
