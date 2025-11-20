#!/bin/bash

# Notarization and DMG creation script for VideoCullingApp
# Usage: ./notarize_and_dmg.sh

set -e  # Exit on any error

echo "=== VideoCullingApp Build, Notarization & DMG Creation ==="
echo ""

# Configuration
APP_NAME="VideoCullingApp"
PROJECT_DIR="/Users/romanwilson/projects/videocull/VideoCullingApp"
PROFILE="notarytool-profile"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$PROJECT_DIR"

# Step 1: Clean
echo "🧹 Step 1: Cleaning previous builds..."
xcodebuild clean -project VideoCullingApp.xcodeproj \
                 -scheme VideoCullingApp \
                 -configuration Release
rm -rf ./build
echo -e "${GREEN}✓ Clean complete${NC}"
echo ""

# Step 2: Archive
echo "📦 Step 2: Archiving app..."
xcodebuild archive \
    -project VideoCullingApp.xcodeproj \
    -scheme VideoCullingApp \
    -configuration Release \
    -archivePath ./build/VideoCullingApp.xcarchive \
    -destination "generic/platform=macOS"
echo -e "${GREEN}✓ Archive complete${NC}"
echo ""

# Step 3: Export
echo "📤 Step 3: Exporting signed app..."
xcodebuild -exportArchive \
    -archivePath ./build/VideoCullingApp.xcarchive \
    -exportPath ./build/Release \
    -exportOptionsPlist ExportOptions.plist
echo -e "${GREEN}✓ Export complete${NC}"
echo ""

cd ./build/Release

# Step 4: Verify signing
echo "🔐 Step 4: Verifying code signature..."
codesign -vvv --deep --strict "${APP_NAME}.app"
echo -e "${GREEN}✓ Signature valid${NC}"
echo ""

# Step 5: Create ZIP
echo "📦 Step 5: Creating ZIP for notarization..."
rm -f "${APP_NAME}.zip"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"
echo -e "${GREEN}✓ ZIP created${NC}"
echo ""

# Step 6: Notarize app
echo "🚀 Step 6: Submitting app to Apple for notarization..."
echo "This may take 1-5 minutes..."
xcrun notarytool submit "${APP_NAME}.zip" \
    --keychain-profile "${PROFILE}" \
    --wait
echo -e "${GREEN}✓ App notarization accepted${NC}"
echo ""

# Step 7: Staple app
echo "📎 Step 7: Stapling notarization ticket to app..."
xcrun stapler staple "${APP_NAME}.app"
echo -e "${GREEN}✓ App stapled${NC}"
echo ""

# Step 8: Create DMG
echo "💿 Step 8: Creating DMG..."
rm -f "${APP_NAME}.dmg"
hdiutil create -volname "Nudge Video Cull" \
    -srcfolder "${APP_NAME}.app" \
    -ov -format UDZO \
    "${APP_NAME}.dmg"
echo -e "${GREEN}✓ DMG created${NC}"
echo ""

# Step 9: Notarize DMG
echo "🚀 Step 9: Notarizing DMG..."
echo "This may take 1-5 minutes..."
xcrun notarytool submit "${APP_NAME}.dmg" \
    --keychain-profile "${PROFILE}" \
    --wait
echo -e "${GREEN}✓ DMG notarization accepted${NC}"
echo ""

# Step 10: Staple DMG
echo "📎 Step 10: Stapling notarization ticket to DMG..."
xcrun stapler staple "${APP_NAME}.dmg"
echo -e "${GREEN}✓ DMG stapled${NC}"
echo ""

# Step 11: Final verification
echo "✅ Step 11: Final verification..."
spctl --assess --verbose=4 "${APP_NAME}.app"
xcrun stapler validate "${APP_NAME}.dmg"
echo -e "${GREEN}✓ All verifications passed${NC}"
echo ""

echo -e "${GREEN}🎉 SUCCESS! Your app is notarized and ready for distribution!${NC}"
echo ""
echo "Distribution files:"
echo "  • App: ${PROJECT_DIR}/build/Release/${APP_NAME}.app"
echo "  • DMG: ${PROJECT_DIR}/build/Release/${APP_NAME}.dmg"
echo ""
