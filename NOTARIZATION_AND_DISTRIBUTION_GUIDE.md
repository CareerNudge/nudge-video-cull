# Notarization and Distribution Guide for VideoCullingApp

Complete step-by-step guide for notarizing and distributing your macOS app outside the Mac App Store.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Create App-Specific Password](#step-1-create-app-specific-password)
3. [Step 2: Store Notarization Credentials](#step-2-store-notarization-credentials)
4. [Step 3: Build and Export Your App](#step-3-build-and-export-your-app)
5. [Step 4: Create a ZIP for Notarization](#step-4-create-a-zip-for-notarization)
6. [Step 5: Submit for Notarization](#step-5-submit-for-notarization)
7. [Step 6: Staple the Notarization Ticket](#step-6-staple-the-notarization-ticket)
8. [Step 7: Create a DMG for Distribution](#step-7-create-a-dmg-for-distribution)
9. [Step 8: Notarize the DMG](#step-8-notarize-the-dmg)
10. [Step 9: Verify Everything](#step-9-verify-everything)
11. [Distribution Options](#distribution-options)
12. [Troubleshooting](#troubleshooting)
13. [Automation Script](#automation-script)

---

## Prerequisites

Before starting, ensure you have:

- ✅ **Developer ID Application certificate** (already installed)
  - Certificate: `Developer ID Application: Nudge AI, LLC (TF3755U948)`
  - Expires: 2030/11/20

- ✅ **Xcode Command Line Tools** installed
  ```bash
  xcode-select --install
  ```

- ✅ **Apple ID** with Developer Program membership
  - Email: `roman.g.wilson@gmail.com`
  - Team ID: `TF3755U948`

- ✅ **Network connection** (notarization happens on Apple's servers)

---

## Step 1: Create App-Specific Password

App-specific passwords are required for notarization (never use your main Apple ID password).

### 1.1 Generate Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID: `roman.g.wilson@gmail.com`
3. Navigate to **Sign-In and Security** section
4. Click **App-Specific Passwords**
5. Click the **+** button or **Generate an app-specific password**
6. Label it: `Notarytool - VideoCullingApp`
7. Click **Create**
8. **IMPORTANT**: Copy the generated password immediately (you won't see it again!)

### 1.2 Save the Password Securely

```bash
# Save to a secure note or password manager
# Format: xxxx-xxxx-xxxx-xxxx (16 characters with dashes)
```

**⚠️ Security Note**: This password grants access to notarization only, not your entire Apple ID.

---

## Step 2: Store Notarization Credentials

Store your credentials in the keychain for automated notarization.

### 2.1 Store Credentials

```bash
# Run this command and enter your app-specific password when prompted
xcrun notarytool store-credentials "notarytool-profile" \
    --apple-id "roman.g.wilson@gmail.com" \
    --team-id "TF3755U948" \
    --password
```

**What happens:**
1. Command prompts for your app-specific password
2. Paste the password you created in Step 1
3. Press Enter
4. Credentials are securely stored in keychain

### 2.2 Verify Credentials

```bash
# List stored credentials
xcrun notarytool history --keychain-profile "notarytool-profile"

# Should show: Successfully authenticated
```

---

## Step 3: Build and Export Your App

Build and sign your app for distribution.

### 3.1 Clean Build

```bash
cd /Users/romanwilson/projects/videocull/VideoCullingApp

# Clean previous builds
xcodebuild clean -project VideoCullingApp.xcodeproj \
                 -scheme VideoCullingApp \
                 -configuration Release
```

### 3.2 Archive the App

```bash
# Create archive with Developer ID signing
xcodebuild archive \
    -project VideoCullingApp.xcodeproj \
    -scheme VideoCullingApp \
    -configuration Release \
    -archivePath ./build/VideoCullingApp.xcarchive \
    -destination "generic/platform=macOS"

# Wait for: ** ARCHIVE SUCCEEDED **
```

### 3.3 Export the Signed App

```bash
# Export using Developer ID distribution
xcodebuild -exportArchive \
    -archivePath ./build/VideoCullingApp.xcarchive \
    -exportPath ./build/Release \
    -exportOptionsPlist ExportOptions.plist

# Wait for: ** EXPORT SUCCEEDED **
```

**Result**: Signed app at `./build/Release/VideoCullingApp.app`

---

## Step 4: Create a ZIP for Notarization

Apple's notarization service requires a ZIP or DMG file.

### 4.1 Create ZIP

```bash
# Create a ZIP of the signed app (preserves signatures)
cd ./build/Release
ditto -c -k --keepParent VideoCullingApp.app VideoCullingApp.zip

# Verify ZIP was created
ls -lh VideoCullingApp.zip
```

**Expected output**: `VideoCullingApp.zip` (size varies, typically 5-20 MB)

### 4.2 Verify Signing Before Notarization

```bash
# Verify the app is properly signed
codesign -vvv --deep --strict VideoCullingApp.app

# Should show: valid on disk, satisfies its Designated Requirement
```

---

## Step 5: Submit for Notarization

Submit your app to Apple's notarization service.

### 5.1 Submit the ZIP

```bash
# Submit for notarization (this uploads to Apple)
xcrun notarytool submit VideoCullingApp.zip \
    --keychain-profile "notarytool-profile" \
    --wait

# The --wait flag makes it wait for completion (usually 1-5 minutes)
```

### 5.2 Understanding the Output

**Successful submission:**
```
Conducting pre-submission checks for VideoCullingApp.zip and initiating connection to the Apple notary service...
Submission ID received
  id: 12345678-1234-1234-1234-123456789012
Successfully uploaded file
  id: 12345678-1234-1234-1234-123456789012
  path: VideoCullingApp.zip
Waiting for processing to complete...
Current status: Accepted........Done.
Processing complete
  id: 12345678-1234-1234-1234-123456789012
  status: Accepted
```

**If rejected:**
```
Processing complete
  id: 12345678-1234-1234-1234-123456789012
  status: Invalid
```

### 5.3 Check Detailed Log (If Needed)

```bash
# If notarization failed, get detailed log
# Replace SUBMISSION_ID with the ID from output above
xcrun notarytool log SUBMISSION_ID \
    --keychain-profile "notarytool-profile" \
    notarization-log.json

# View the log
cat notarization-log.json
```

### 5.4 Alternative: Submit Without Waiting

```bash
# Submit and check status later
xcrun notarytool submit VideoCullingApp.zip \
    --keychain-profile "notarytool-profile"

# Check status later
xcrun notarytool info SUBMISSION_ID \
    --keychain-profile "notarytool-profile"

# View submission history
xcrun notarytool history \
    --keychain-profile "notarytool-profile"
```

---

## Step 6: Staple the Notarization Ticket

After successful notarization, staple the ticket to your app.

### 6.1 What is Stapling?

Stapling attaches the notarization ticket to your app bundle. This allows:
- ✅ Offline verification (no internet needed to verify notarization)
- ✅ Faster Gatekeeper checks
- ✅ Better user experience

### 6.2 Staple the Ticket

```bash
# Staple the notarization ticket to the app
xcrun stapler staple VideoCullingApp.app

# Expected output:
# Processing: VideoCullingApp.app
# The staple and validate action worked!
```

### 6.3 Verify Stapling

```bash
# Verify the ticket is stapled
xcrun stapler validate VideoCullingApp.app

# Expected output:
# Processing: VideoCullingApp.app
# The validate action worked!
```

### 6.4 Check Gatekeeper Assessment

```bash
# Test Gatekeeper's assessment of the app
spctl --assess --verbose=4 VideoCullingApp.app

# Expected output:
# VideoCullingApp.app: accepted
# source=Notarized Developer ID
# origin=Developer ID Application: Nudge AI, LLC (TF3755U948)
```

**✅ Success!** Your app is now notarized and will open without warnings on any Mac.

---

## Step 7: Create a DMG for Distribution

A DMG provides a professional, easy-to-distribute package.

### 7.1 Basic DMG Creation

```bash
# Create a simple DMG
hdiutil create -volname "Nudge Video Cull" \
    -srcfolder VideoCullingApp.app \
    -ov -format UDZO \
    VideoCullingApp.dmg

# Result: VideoCullingApp.dmg
```

### 7.2 Create a Styled DMG with Background (Optional)

```bash
# Create a more professional DMG with custom styling
# 1. Create a temporary folder
mkdir dmg_staging
cp -R VideoCullingApp.app dmg_staging/

# 2. Create symlink to Applications
ln -s /Applications dmg_staging/Applications

# 3. Create DMG with custom settings
hdiutil create -volname "Nudge Video Cull" \
    -srcfolder dmg_staging \
    -ov -format UDRW \
    temp.dmg

# 4. Mount the DMG
hdiutil attach temp.dmg

# 5. Open Finder and customize the DMG window
# - Drag VideoCullingApp.app to the left
# - Drag Applications to the right
# - Set background image (if you have one)
# - Set icon positions and window size
# - View → Show View Options → Adjust icon size, grid spacing

# 6. Unmount
hdiutil detach /Volumes/Nudge\ Video\ Cull

# 7. Convert to compressed read-only
hdiutil convert temp.dmg -format UDZO -o VideoCullingApp.dmg

# 8. Clean up
rm temp.dmg
rm -rf dmg_staging
```

### 7.3 Verify DMG Contents

```bash
# Mount and verify
hdiutil attach VideoCullingApp.dmg
ls -la /Volumes/Nudge\ Video\ Cull/
hdiutil detach /Volumes/Nudge\ Video\ Cull
```

---

## Step 8: Notarize the DMG

The DMG itself also needs to be notarized.

### 8.1 Submit DMG for Notarization

```bash
# Submit the DMG
xcrun notarytool submit VideoCullingApp.dmg \
    --keychain-profile "notarytool-profile" \
    --wait

# Wait for: status: Accepted
```

### 8.2 Staple the DMG

```bash
# Staple the notarization ticket to the DMG
xcrun stapler staple VideoCullingApp.dmg

# Expected output:
# Processing: VideoCullingApp.dmg
# The staple and validate action worked!
```

### 8.3 Verify DMG Notarization

```bash
# Verify the DMG is notarized
xcrun stapler validate VideoCullingApp.dmg
spctl --assess --verbose=4 --type open --context context:primary-signature VideoCullingApp.dmg

# Both should show successful notarization
```

---

## Step 9: Verify Everything

Final verification before distribution.

### 9.1 Comprehensive Verification Checklist

```bash
# 1. Verify app signature
codesign -vvv --deep --strict ./build/Release/VideoCullingApp.app

# 2. Verify app notarization
spctl --assess --verbose=4 ./build/Release/VideoCullingApp.app

# 3. Verify app stapling
xcrun stapler validate ./build/Release/VideoCullingApp.app

# 4. Verify DMG signature
codesign -vvv VideoCullingApp.dmg

# 5. Verify DMG notarization
spctl --assess --verbose=4 --type open --context context:primary-signature VideoCullingApp.dmg

# 6. Verify DMG stapling
xcrun stapler validate VideoCullingApp.dmg
```

### 9.2 Test on a Clean Mac

**Best Practice**: Test the DMG on a separate Mac or user account:

1. Copy `VideoCullingApp.dmg` to another Mac (via AirDrop, USB, etc.)
2. Double-click the DMG
3. Double-click the app
4. **Should open immediately with no warnings** ✅

### 9.3 Test Gatekeeper Assessment

```bash
# This simulates what happens when a user downloads your app
xattr -d com.apple.quarantine VideoCullingApp.dmg
xattr -c VideoCullingApp.dmg

# Re-add quarantine (simulates download)
xattr -w com.apple.quarantine "0001;$(date +%s);Safari" VideoCullingApp.dmg

# Try to open - should work without warnings
open VideoCullingApp.dmg
```

---

## Distribution Options

Now that your app is notarized, here are your distribution options:

### Option 1: Direct Download from Website

**Setup:**
1. Upload `VideoCullingApp.dmg` to your web server
2. Provide download link on your website
3. Users download and open - no warnings!

**Example HTML:**
```html
<a href="downloads/VideoCullingApp.dmg" download>
  Download Nudge Video Cull (Latest Version)
</a>
```

### Option 2: GitHub Releases

**Setup:**
1. Go to your GitHub repository
2. Click **Releases** → **Create a new release**
3. Tag version (e.g., `v1.0.0`)
4. Upload `VideoCullingApp.dmg` as a release asset
5. Publish release

**Users can then:**
```bash
# Download via command line
curl -L -O https://github.com/your-username/VideoCullingApp/releases/download/v1.0.0/VideoCullingApp.dmg
```

### Option 3: Cloud Storage (Dropbox, Google Drive, etc.)

**Setup:**
1. Upload `VideoCullingApp.dmg` to cloud storage
2. Generate shareable link
3. Share link with users

**⚠️ Note**: Some cloud services add extra quarantine attributes. Test thoroughly.

### Option 4: Email Distribution

For beta testers or limited distribution:
1. Attach `VideoCullingApp.dmg` to email (if size permits)
2. Or share via file transfer services
3. Recipients can open without warnings

---

## Troubleshooting

### Issue 1: "The app can't be opened"

**Symptoms:**
```
"VideoCullingApp.app" can't be opened because Apple cannot check
it for malicious software.
```

**Causes & Solutions:**

1. **App not notarized**
   ```bash
   # Check notarization status
   spctl --assess --verbose=4 VideoCullingApp.app

   # If shows "unnotarized" - resubmit for notarization
   ```

2. **Ticket not stapled**
   ```bash
   # Staple the ticket
   xcrun stapler staple VideoCullingApp.app
   ```

3. **Quarantine attribute issues**
   ```bash
   # Check quarantine attributes
   xattr -l VideoCullingApp.app

   # Remove and re-apply if needed
   xattr -cr VideoCullingApp.app
   ```

### Issue 2: Notarization Failed

**Get detailed error log:**
```bash
# Get the submission ID from failed submission
xcrun notarytool log SUBMISSION_ID \
    --keychain-profile "notarytool-profile" \
    error-log.json

# Common issues in log:
cat error-log.json | grep -i "severity\|issue"
```

**Common notarization issues:**

1. **Invalid signature**
   ```bash
   # Re-sign the app
   codesign --force --deep --sign "Developer ID Application: Nudge AI, LLC (TF3755U948)" \
       VideoCullingApp.app
   ```

2. **Hardened Runtime not enabled**
   - Add `--options runtime` to codesign command
   - Or enable in Xcode: Target → Signing & Capabilities → Hardened Runtime

3. **Entitlements issues**
   ```bash
   # Check entitlements
   codesign -d --entitlements :- VideoCullingApp.app
   ```

4. **Timestamp issues**
   ```bash
   # Re-sign with timestamp
   codesign --force --deep --timestamp \
       --sign "Developer ID Application: Nudge AI, LLC (TF3755U948)" \
       VideoCullingApp.app
   ```

### Issue 3: DMG Won't Mount

```bash
# Verify DMG integrity
hdiutil verify VideoCullingApp.dmg

# If corrupted, recreate
hdiutil create -srcfolder VideoCullingApp.app -volname "Nudge Video Cull" \
    -format UDZO VideoCullingApp-new.dmg
```

### Issue 4: "Credentials are invalid"

```bash
# Re-store credentials
xcrun notarytool store-credentials "notarytool-profile" \
    --apple-id "roman.g.wilson@gmail.com" \
    --team-id "TF3755U948" \
    --password
```

### Issue 5: Notarization Takes Too Long

**Normal time**: 1-5 minutes
**If longer**: Check status manually

```bash
# Check submission status
xcrun notarytool history --keychain-profile "notarytool-profile"

# Get specific submission info
xcrun notarytool info SUBMISSION_ID --keychain-profile "notarytool-profile"
```

---

## Automation Script

Save this script for easy notarization of future builds.

### notarize.sh

```bash
#!/bin/bash

# Notarization automation script for VideoCullingApp
# Usage: ./notarize.sh

set -e  # Exit on any error

echo "=== VideoCullingApp Notarization Script ==="
echo ""

# Configuration
APP_NAME="VideoCullingApp"
BUNDLE_ID="ai.careernudge.VideoCullingApp"
TEAM_ID="TF3755U948"
PROFILE="notarytool-profile"
BUILD_DIR="./build/Release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verify app exists
echo "📦 Step 1: Verifying app..."
if [ ! -d "${BUILD_DIR}/${APP_NAME}.app" ]; then
    echo -e "${RED}Error: App not found at ${BUILD_DIR}/${APP_NAME}.app${NC}"
    echo "Run build first!"
    exit 1
fi
echo -e "${GREEN}✓ App found${NC}"
echo ""

# Step 2: Verify signing
echo "🔐 Step 2: Verifying code signature..."
if ! codesign -vvv --deep --strict "${BUILD_DIR}/${APP_NAME}.app" 2>&1 | grep -q "valid on disk"; then
    echo -e "${RED}Error: App signature is invalid${NC}"
    exit 1
fi
echo -e "${GREEN}✓ App signature valid${NC}"
echo ""

# Step 3: Create ZIP
echo "📦 Step 3: Creating ZIP for notarization..."
cd "${BUILD_DIR}"
rm -f "${APP_NAME}.zip"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"
echo -e "${GREEN}✓ ZIP created: ${APP_NAME}.zip${NC}"
echo ""

# Step 4: Submit for notarization
echo "🚀 Step 4: Submitting to Apple for notarization..."
echo "This may take 1-5 minutes..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "${APP_NAME}.zip" \
    --keychain-profile "${PROFILE}" \
    --wait 2>&1)

echo "$SUBMIT_OUTPUT"

if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓ Notarization accepted!${NC}"
else
    echo -e "${RED}✗ Notarization failed${NC}"

    # Try to get submission ID and log
    SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    if [ ! -z "$SUBMISSION_ID" ]; then
        echo "Fetching detailed log..."
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "${PROFILE}" error-log.json
        echo "Error log saved to: error-log.json"
    fi
    exit 1
fi
echo ""

# Step 5: Staple the app
echo "📎 Step 5: Stapling notarization ticket to app..."
if ! xcrun stapler staple "${APP_NAME}.app" 2>&1 | grep -q "action worked"; then
    echo -e "${RED}Error: Stapling failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ App stapled${NC}"
echo ""

# Step 6: Verify stapling
echo "✅ Step 6: Verifying stapling..."
if ! xcrun stapler validate "${APP_NAME}.app" 2>&1 | grep -q "validate action worked"; then
    echo -e "${RED}Error: Staple validation failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Stapling verified${NC}"
echo ""

# Step 7: Create DMG
echo "💿 Step 7: Creating DMG..."
rm -f "${APP_NAME}.dmg"
hdiutil create -volname "Nudge Video Cull" \
    -srcfolder "${APP_NAME}.app" \
    -ov -format UDZO \
    "${APP_NAME}.dmg"
echo -e "${GREEN}✓ DMG created: ${APP_NAME}.dmg${NC}"
echo ""

# Step 8: Notarize DMG
echo "🚀 Step 8: Notarizing DMG..."
echo "This may take 1-5 minutes..."
DMG_OUTPUT=$(xcrun notarytool submit "${APP_NAME}.dmg" \
    --keychain-profile "${PROFILE}" \
    --wait 2>&1)

echo "$DMG_OUTPUT"

if echo "$DMG_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓ DMG notarization accepted!${NC}"
else
    echo -e "${RED}✗ DMG notarization failed${NC}"
    exit 1
fi
echo ""

# Step 9: Staple DMG
echo "📎 Step 9: Stapling notarization ticket to DMG..."
if ! xcrun stapler staple "${APP_NAME}.dmg" 2>&1 | grep -q "action worked"; then
    echo -e "${RED}Error: DMG stapling failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ DMG stapled${NC}"
echo ""

# Step 10: Final verification
echo "✅ Step 10: Final verification..."

# Verify app
if ! spctl --assess --verbose=4 "${APP_NAME}.app" 2>&1 | grep -q "accepted"; then
    echo -e "${YELLOW}Warning: App Gatekeeper check failed${NC}"
else
    echo -e "${GREEN}✓ App passes Gatekeeper${NC}"
fi

# Verify DMG
if ! xcrun stapler validate "${APP_NAME}.dmg" 2>&1 | grep -q "validate action worked"; then
    echo -e "${YELLOW}Warning: DMG validation failed${NC}"
else
    echo -e "${GREEN}✓ DMG validated${NC}"
fi

echo ""
echo -e "${GREEN}🎉 SUCCESS! Your app is notarized and ready for distribution!${NC}"
echo ""
echo "Distribution files:"
echo "  • App: ${BUILD_DIR}/${APP_NAME}.app"
echo "  • DMG: ${BUILD_DIR}/${APP_NAME}.dmg"
echo ""
echo "Next steps:"
echo "  1. Test the DMG on another Mac"
echo "  2. Upload to your distribution channel"
echo "  3. Celebrate! 🎊"
```

### Making the Script Executable

```bash
# Save the script
# Then make it executable
chmod +x notarize.sh

# Run it
./notarize.sh
```

---

## Quick Reference Commands

```bash
# Store credentials (one-time setup)
xcrun notarytool store-credentials "notarytool-profile" \
    --apple-id "roman.g.wilson@gmail.com" \
    --team-id "TF3755U948" --password

# Build and export
xcodebuild clean archive -project VideoCullingApp.xcodeproj \
    -scheme VideoCullingApp -configuration Release \
    -archivePath ./build/VideoCullingApp.xcarchive \
    -destination "generic/platform=macOS"

xcodebuild -exportArchive -archivePath ./build/VideoCullingApp.xcarchive \
    -exportPath ./build/Release -exportOptionsPlist ExportOptions.plist

# Create ZIP and notarize app
cd ./build/Release
ditto -c -k --keepParent VideoCullingApp.app VideoCullingApp.zip
xcrun notarytool submit VideoCullingApp.zip --keychain-profile "notarytool-profile" --wait
xcrun stapler staple VideoCullingApp.app

# Create and notarize DMG
hdiutil create -volname "Nudge Video Cull" -srcfolder VideoCullingApp.app \
    -ov -format UDZO VideoCullingApp.dmg
xcrun notarytool submit VideoCullingApp.dmg --keychain-profile "notarytool-profile" --wait
xcrun stapler staple VideoCullingApp.dmg

# Verify everything
spctl --assess --verbose=4 VideoCullingApp.app
xcrun stapler validate VideoCullingApp.dmg
```

---

## Additional Resources

- [Apple Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [notarytool User Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Gatekeeper and Runtime Protection](https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web)

---

## Support

If you encounter issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Apple's notarization logs
3. Verify all certificates are valid and not expired
4. Check that Xcode is up to date

**Your Configuration:**
- **Team ID**: TF3755U948
- **Organization**: Nudge AI, LLC
- **Bundle ID**: ai.careernudge.VideoCullingApp
- **Apple ID**: roman.g.wilson@gmail.com
- **Certificate**: Developer ID Application (expires 2030/11/20)

---

**Last Updated**: 2025-11-19
**App Version**: 1.0
**Xcode Version**: 16.1
