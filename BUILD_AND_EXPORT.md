# Building and Exporting Nudge Video Cull

## Prerequisites

1. **macOS** (required for building macOS apps)
2. **Xcode** (latest version recommended)
3. **Apple Developer Account** (free account works for local development)

## Step 1: Add Missing Files to Xcode Project

Before building, you need to add files that were created via code:

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Right-click on the "Views" folder in Project Navigator
3. Select "Add Files to 'VideoCullingApp'..."
4. Add these files:
   - `Views/ProcessingProgressView.swift`
   - `Views/WelcomeView.swift`
5. Make sure "Copy items if needed" is **unchecked**
6. Click "Add"

## Step 2: Configure Code Signing

### For Local Use (No Distribution)

1. In Xcode, select the project in Project Navigator
2. Select the "VideoCullingApp" target
3. Go to "Signing & Capabilities" tab
4. Check "Automatically manage signing"
5. Select your Team (your Apple ID)
6. Xcode will automatically create a development certificate

### For Distribution to Others

You'll need a paid Apple Developer account ($99/year) to distribute outside the App Store.

## Step 3: Build for Release

### Option A: Build for Running Locally

1. In Xcode menu: **Product → Scheme → Edit Scheme**
2. Select "Run" in the left sidebar
3. Change "Build Configuration" to **Release**
4. Click "Close"
5. Press **Cmd + B** to build
6. The app will be in:
   ```
   ~/Library/Developer/Xcode/DerivedData/VideoCullingApp-*/Build/Products/Release/
   ```

### Option B: Archive for Distribution

1. In Xcode menu: **Product → Destination → Any Mac**
2. In Xcode menu: **Product → Archive**
3. Wait for the archive to complete
4. The Organizer window will open automatically

## Step 4: Export the Application

### For Personal Use (Easiest)

1. In the Organizer window, select your archive
2. Click **Distribute App**
3. Select **Copy App**
4. Click **Next**
5. Choose a location to save
6. Click **Export**

The exported `.app` file can now be:
- Moved to your Applications folder
- Copied to other Macs you own
- Run directly by double-clicking

### For Distribution to Others (Requires Paid Developer Account)

1. In the Organizer window, select your archive
2. Click **Distribute App**
3. Select **Developer ID** (for distribution outside App Store)
4. Follow the prompts to notarize the app
5. Export the notarized app

## Step 5: Install and Run

### Installing

1. Drag `VideoCullingApp.app` to your Applications folder
2. Or run it directly from wherever you saved it

### First Launch

If you get a security warning:

1. Right-click (or Control-click) on the app
2. Select "Open" from the context menu
3. Click "Open" in the dialog
4. macOS will remember this choice

**Alternative:**
1. Open System Preferences → Security & Privacy
2. Click "Open Anyway" next to the blocked app message

## Quick Build Commands (Terminal)

If you prefer command line:

```bash
# Navigate to project directory
cd /Users/romanwilson/projects/videocull/VideoCullingApp

# Build release version
xcodebuild -project VideoCullingApp.xcodeproj \
           -scheme VideoCullingApp \
           -configuration Release \
           -derivedDataPath ./build

# The app will be in:
# ./build/Build/Products/Release/VideoCullingApp.app
```

## Creating a DMG Installer (Optional)

To create a professional installer:

1. Create a new folder named "Nudge Video Cull"
2. Copy `VideoCullingApp.app` into it
3. Create an alias to Applications folder
4. Use Disk Utility:
   - File → New Image → Image from Folder
   - Select your folder
   - Save as "Nudge Video Cull Installer.dmg"

## Troubleshooting

### "Cannot verify developer" error
- Right-click app → Open (first time only)
- Or: System Preferences → Security → "Open Anyway"

### Build fails with missing files
- Make sure ProcessingProgressView.swift and WelcomeView.swift are added to Xcode project
- Check XCODE_SETUP_NEEDED.md for instructions

### Code signing issues
- Make sure you're signed in with your Apple ID in Xcode
- Preferences → Accounts → Add Apple ID
- Select your account in Signing & Capabilities

### App crashes on launch
- Build with Debug configuration first to see error messages
- Check Console.app for crash logs

## Recommended: Clean Build

Before building for distribution:

1. **Product → Clean Build Folder** (Shift + Cmd + K)
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Quit and restart Xcode
4. Build again

## File Locations

- **Development Build**: `~/Library/Developer/Xcode/DerivedData/VideoCullingApp-*/Build/Products/Debug/`
- **Release Build**: `~/Library/Developer/Xcode/DerivedData/VideoCullingApp-*/Build/Products/Release/`
- **Archives**: `~/Library/Developer/Xcode/Archives/`

## Next Steps

After building successfully:

1. Test the app thoroughly on your Mac
2. If distributing: Test on a different Mac without Xcode installed
3. For App Store: Follow APP_STORE_MIGRATION_STEPS.md
4. For wider distribution: Get Apple Developer ID certificate

## Support

For issues specific to this app, check:
- COMPLETED_FEATURES.md - What's implemented
- XCODE_SETUP_NEEDED.md - Required manual steps
- APP_STORE_MIGRATION_STEPS.md - App Store preparation

For Xcode/macOS issues:
- Apple Developer Documentation
- Xcode Help menu
- Stack Overflow
