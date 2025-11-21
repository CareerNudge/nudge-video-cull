#!/bin/bash
#
# Quick DMG creation script (no notarization)
# For development and testing
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="VideoCullingApp"
DISPLAY_NAME="Nudge Video Cull"
PROJECT_DIR="/Users/romanwilson/projects/videocull/VideoCullingApp"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Creating DMG for ${DISPLAY_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd "$PROJECT_DIR"

# Step 1: Clean
echo -e "${YELLOW}[1/4]${NC} Cleaning previous builds..."
xcodebuild clean -project VideoCullingApp.xcodeproj \
                 -scheme VideoCullingApp \
                 -configuration Release \
                 > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Clean complete"
echo ""

# Step 2: Build
echo -e "${YELLOW}[2/4]${NC} Building Release version..."
xcodebuild build \
    -project VideoCullingApp.xcodeproj \
    -scheme VideoCullingApp \
    -configuration Release \
    -derivedDataPath ./build \
    | grep -E '(▸|✓|error:|warning:|BUILD)' || true
echo -e "${GREEN}✓${NC} Build complete"
echo ""

# Step 3: Prepare DMG staging
echo -e "${YELLOW}[3/4]${NC} Preparing DMG staging area..."
RELEASE_DIR="./release"
DMG_STAGING_DIR="$RELEASE_DIR/dmg_staging"
APP_PATH="./build/Build/Products/Release/${APP_NAME}.app"

rm -rf "$RELEASE_DIR"
mkdir -p "$DMG_STAGING_DIR"

# Copy app
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"

# Create Applications symlink for drag-and-drop installation
ln -s /Applications "$DMG_STAGING_DIR/Applications"

echo -e "${GREEN}✓${NC} Staging area ready"
echo ""

# Step 4: Create DMG
echo -e "${YELLOW}[4/4]${NC} Creating DMG..."
DMG_NAME="${DISPLAY_NAME// /_}_Beta.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

rm -f "$DMG_PATH"
hdiutil create -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" \
    > /dev/null 2>&1

echo -e "${GREEN}✓${NC} DMG created"
echo ""

# Cleanup
rm -rf "$DMG_STAGING_DIR"

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SUCCESS!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}DMG Location:${NC}"
echo "  $PROJECT_DIR/$DMG_PATH"
echo ""
echo -e "${BLUE}📦 DMG Contents:${NC}"
echo "  • Nudge Video Cull.app"
echo "  • Applications folder shortcut (for easy drag-install)"
echo "  • Beta expiration: April 1, 2026"
echo ""
echo -e "${YELLOW}Note:${NC} This DMG is not notarized."
echo "For distribution, use: ./scripts/notarize_and_package.sh"
echo ""
