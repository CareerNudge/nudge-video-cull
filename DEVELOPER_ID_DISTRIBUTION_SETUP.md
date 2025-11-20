# Developer ID Distribution Setup - Complete

## ✅ Configuration Summary

All necessary setup for distributing VideoCullingApp outside the Mac App Store has been completed.

## 📋 Apple Developer Portal Configuration

### App ID
- **Name**: Nudge Video Cull
- **Bundle Identifier**: `ai.careernudge.VideoCullingApp`
- **Team ID**: TF3755U948
- **Organization**: Nudge AI, LLC
- **Platform**: iOS, iPadOS, macOS, tvOS, watchOS, visionOS

### Developer ID Certificate
- **Type**: Developer ID Application
- **Name**: Nudge AI, LLC
- **Team ID**: TF3755U948
- **Expiration**: 2030/11/20 (5 years)
- **Created By**: Roman Wilson (roman.g.wilson@gmail.com)
- **Certificate ID**: ZUYJY3LX9U
- **Hash**: E5E5AE4860F82F4502BCC517F390F94686ED2F95

## 🔧 Xcode Project Configuration

The following settings have been configured in `VideoCullingApp.xcodeproj/project.pbxproj`:

### Bundle Identifier
- **Changed from**: `com.yourcompany.VideoCullingApp`
- **Changed to**: `ai.careernudge.VideoCullingApp`

### Code Signing Settings (Debug & Release)
```
PRODUCT_BUNDLE_IDENTIFIER = ai.careernudge.VideoCullingApp
CODE_SIGN_IDENTITY = "Developer ID Application"
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = TF3755U948
```

## 🔐 Keychain Installation

The following have been installed in your Login Keychain:
1. **Private Key**: `/tmp/VideoCullingApp.key` (imported)
2. **Certificate**: `~/Downloads/developerID_application.cer` (imported)

**Signing Identity**:
```
Developer ID Application: Nudge AI, LLC (TF3755U948)
```

## 🚀 Building for Distribution

### Option 1: Build with Xcode
1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Select your Mac as the destination
3. Go to **Product → Archive**
4. In the Organizer, select the archive
5. Click **Distribute App**
6. Choose **Developer ID** for distribution outside the Mac App Store
7. Follow the prompts to export a signed app

### Option 2: Build with Command Line
```bash
# Clean and build release version
xcodebuild clean -project VideoCullingApp.xcodeproj \
                 -scheme VideoCullingApp \
                 -configuration Release

# Archive the app
xcodebuild archive -project VideoCullingApp.xcodeproj \
                   -scheme VideoCullingApp \
                   -configuration Release \
                   -archivePath ./build/VideoCullingApp.xcarchive

# Export for Developer ID distribution
xcodebuild -exportArchive \
           -archivePath ./build/VideoCullingApp.xcarchive \
           -exportPath ./build/Release \
           -exportOptionsPlist ExportOptions.plist
```

### ExportOptions.plist Template
Create this file for command-line exports:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TF3755U948</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

## 📦 Notarization (Required for macOS Distribution)

Apps distributed outside the Mac App Store must be notarized by Apple:

### Notarization Process
```bash
# 1. Create an app-specific password at appleid.apple.com
# 2. Store credentials in keychain
xcrun notarytool store-credentials "notarytool-profile" \
    --apple-id "roman.g.wilson@gmail.com" \
    --team-id "TF3755U948" \
    --password "app-specific-password"

# 3. Submit app for notarization
xcrun notarytool submit VideoCullingApp.app.zip \
    --keychain-profile "notarytool-profile" \
    --wait

# 4. Staple notarization ticket to app
xcrun stapler staple VideoCullingApp.app
```

### Creating DMG for Distribution
```bash
# Create a disk image for easy distribution
hdiutil create -volname "Nudge Video Cull" \
               -srcfolder ./build/Release/VideoCullingApp.app \
               -ov -format UDZO \
               VideoCullingApp.dmg

# Notarize the DMG
xcrun notarytool submit VideoCullingApp.dmg \
    --keychain-profile "notarytool-profile" \
    --wait

# Staple notarization to DMG
xcrun stapler staple VideoCullingApp.dmg
```

## 🔍 Verification

### Verify Code Signature
```bash
# Check if app is properly signed
codesign -vvv --deep --strict VideoCullingApp.app

# Display signing information
codesign -d -vvv VideoCullingApp.app

# Verify Developer ID certificate
spctl -a -vv VideoCullingApp.app
```

### Verify Notarization
```bash
# Check notarization status
xcrun stapler validate VideoCullingApp.app

# Check Gatekeeper status
spctl --assess --verbose=4 VideoCullingApp.app
```

## 🔑 Important Files to Back Up

**CRITICAL**: Store these files securely for future builds:
1. **Private Key**: `/tmp/VideoCullingApp.key`
   - Location: Already imported to Keychain
   - Backup: Export from Keychain as .p12 file
2. **Certificate**: `~/Downloads/developerID_application.cer`
   - Already installed in Keychain
3. **CSR File**: `/tmp/VideoCullingApp.certSigningRequest`
   - Can be regenerated if needed

### Export Certificate + Private Key as .p12
```bash
# Export for backup/sharing with CI systems
security export -k ~/Library/Keychains/login.keychain-db \
                -t identities \
                -f pkcs12 \
                -o ~/Desktop/VideoCullingApp_DeveloperID.p12 \
                -P "your-password-here"
```

## 📚 Additional Resources

- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Distribution Methods](https://developer.apple.com/help/account/manage-credentials)

## ⚠️ Security Notes

1. **Never commit private keys** to version control
2. **Keep .p12 files encrypted** and in secure storage
3. **Rotate certificates** before expiration (2030/11/20)
4. **Use app-specific passwords** for notarization (not your main Apple ID password)
5. **Consider using CI/CD** for automated signing and distribution

## 🎯 Next Steps

1. ✅ Configuration complete - ready to build
2. Build and archive your app in Xcode
3. Create app-specific password for notarization
4. Submit for notarization
5. Create DMG for distribution
6. Distribute via your website or other channels

---

**Setup completed on**: 2025-11-19
**Configured by**: Claude Code
**Certificate expires**: 2030-11-20
