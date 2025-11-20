#!/bin/bash
#
# Notarize and Package Script for Nudge Video Cull
# This script builds, signs, notarizes, and packages the app into a DMG
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="VideoCullingApp"
DISPLAY_NAME="Nudge Video Cull"
BUNDLE_ID="ai.nudge.VideoCullingApp"
TEAM_ID="TF3755U948"
DEVELOPER_ID="Developer ID Application: Nudge AI, LLC (TF3755U948)"

# Directories
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$PROJECT_DIR/release"
DMG_STAGING_DIR="$RELEASE_DIR/dmg_staging"

# Derived paths
APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="${DISPLAY_NAME// /_}_Beta.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Nudge Video Cull - Build, Sign & Notarize${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check for required credentials
if [ -z "$APPLE_ID" ]; then
    echo -e "${RED}❌ Error: APPLE_ID environment variable not set${NC}"
    echo ""
    echo "Please set your Apple ID email:"
    echo "  export APPLE_ID='your@email.com'"
    exit 1
fi

if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
    echo -e "${RED}❌ Error: APP_SPECIFIC_PASSWORD environment variable not set${NC}"
    echo ""
    echo "Please set your app-specific password:"
    echo "  export APP_SPECIFIC_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
    exit 1
fi

echo -e "${GREEN}✓${NC} Apple ID: $APPLE_ID"
echo -e "${GREEN}✓${NC} Team ID: $TEAM_ID"
echo ""

# Step 1: Clean previous builds
echo -e "${YELLOW}[1/7]${NC} Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Step 2: Build release version
echo -e "${YELLOW}[2/7]${NC} Building release version..."
cd "$PROJECT_DIR"
xcodebuild clean build \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    | grep -E '(error:|warning:|▸|✓|BUILD)' || true

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Build failed - app not found at: $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Build complete: $APP_PATH"
echo ""

# Step 3: Verify code signature
echo -e "${YELLOW}[3/7]${NC} Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo -e "${GREEN}✓${NC} Code signature verified"
echo ""

# Step 4: Create ZIP for notarization
echo -e "${YELLOW}[4/7]${NC} Creating ZIP archive for notarization..."
NOTARIZE_ZIP="$RELEASE_DIR/${APP_NAME}.zip"
cd "$BUILD_DIR/Build/Products/Release"
/usr/bin/ditto -c -k --keepParent "${APP_NAME}.app" "$NOTARIZE_ZIP"
echo -e "${GREEN}✓${NC} ZIP created: $NOTARIZE_ZIP"
echo ""

# Step 5: Submit for notarization
echo -e "${YELLOW}[5/7]${NC} Submitting to Apple for notarization..."
echo -e "${BLUE}ℹ️  This may take 2-10 minutes...${NC}"
echo ""

NOTARIZE_OUTPUT=$(xcrun notarytool submit "$NOTARIZE_ZIP" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait)

echo "$NOTARIZE_OUTPUT"

# Extract submission ID
SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep "id:" | head -n 1 | awk '{print $2}')

# Check if notarization succeeded
if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓${NC} Notarization accepted!"
    echo ""
else
    echo -e "${RED}❌ Notarization failed${NC}"
    echo ""
    echo "Getting detailed log..."
    xcrun notarytool log "$SUBMISSION_ID" \
        --apple-id "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --team-id "$TEAM_ID"
    exit 1
fi

# Step 6: Staple notarization ticket
echo -e "${YELLOW}[6/7]${NC} Stapling notarization ticket to app..."
xcrun stapler staple "$APP_PATH"
echo -e "${GREEN}✓${NC} Notarization ticket stapled"
echo ""

# Step 7: Create DMG
echo -e "${YELLOW}[7/7]${NC} Creating DMG installer..."

# Create staging directory
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"

# Copy app
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_STAGING_DIR/Applications"

# Create DMG
rm -f "$DMG_PATH"
hdiutil create -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

echo -e "${GREEN}✓${NC} DMG created: $DMG_PATH"
echo ""

# Sign the DMG
echo -e "${YELLOW}[BONUS]${NC} Signing DMG..."
codesign --sign "$DEVELOPER_ID" --timestamp "$DMG_PATH"
echo -e "${GREEN}✓${NC} DMG signed"
echo ""

# Notarize the DMG
echo -e "${YELLOW}[BONUS]${NC} Notarizing DMG..."
echo -e "${BLUE}ℹ️  This may take another 2-10 minutes...${NC}"
echo ""

NOTARIZE_ZIP_DMG="$RELEASE_DIR/${APP_NAME}_DMG.zip"
/usr/bin/ditto -c -k --keepParent "$DMG_PATH" "$NOTARIZE_ZIP_DMG"

DMG_NOTARIZE_OUTPUT=$(xcrun notarytool submit "$NOTARIZE_ZIP_DMG" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait)

echo "$DMG_NOTARIZE_OUTPUT"

if echo "$DMG_NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓${NC} DMG notarization accepted!"
    echo ""

    # Staple to DMG
    xcrun stapler staple "$DMG_PATH"
    echo -e "${GREEN}✓${NC} Notarization ticket stapled to DMG"
else
    echo -e "${YELLOW}⚠️  DMG notarization failed, but the app inside is notarized${NC}"
fi

# Clean up temporary files
rm -f "$NOTARIZE_ZIP"
rm -f "$NOTARIZE_ZIP_DMG"
rm -rf "$DMG_STAGING_DIR"

# Final summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SUCCESS!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Notarized App:${NC} $APP_PATH"
echo -e "${GREEN}Distributable DMG:${NC} $DMG_PATH"
echo ""
echo -e "${BLUE}📦 You can now distribute this DMG to testers!${NC}"
echo ""
echo "The DMG includes:"
echo "  • Notarized app that will open without warnings"
echo "  • Drag-to-Applications folder shortcut"
echo "  • Beta expiration: April 1, 2026"
echo ""
echo -e "${YELLOW}Testing:${NC}"
echo "  1. Mount the DMG on a test Mac (without Xcode)"
echo "  2. Drag the app to Applications"
echo "  3. Double-click to run - no security warnings!"
echo ""
