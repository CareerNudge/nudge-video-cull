# Core Data Migration: Add Video Dimensions

## Summary
✅ **COMPLETED** - Added `videoWidth` and `videoHeight` attributes to the `ManagedVideoAsset` entity to display video resolution in the metadata view.

## Implementation Status

All changes have been completed and the app is ready to use:

✅ Core Data Model - Added videoWidth and videoHeight attributes (Integer 32)
✅ FileScannerService.swift - Extracts dimensions from AVAssetTrack.naturalSize
✅ MetadataView.swift - Displays resolution with common format names (4K, 1080p, etc.)
✅ Build successful - All code compiles and works

## Previous Manual Steps (No Longer Required)

### Step 1: Open the Core Data Model
1. Open Xcode
2. In the Project Navigator, navigate to: `VideoCullingApp.xcdatamodeld`
3. Click on `VideoCullingApp.xcdatamodeld` to open the visual editor

### Step 2: Add New Attributes
1. Select the **ManagedVideoAsset** entity in the left panel
2. In the Attributes section, click the **+** button to add a new attribute
3. Add the first attribute:
   - **Name**: `videoWidth`
   - **Type**: `Integer 32`
   - **Default Value**: `0`
   - **Optional**: ✅ (checked)
   - **Use Scalar Type**: ✅ (checked)

4. Click the **+** button again to add another attribute
5. Add the second attribute:
   - **Name**: `videoHeight`
   - **Type**: `Integer 32`
   - **Default Value**: `0`
   - **Optional**: ✅ (checked)
   - **Use Scalar Type**: ✅ (checked)

### Step 3: Save the Model
1. Press `⌘S` to save the Core Data model
2. Xcode will automatically regenerate the `ManagedVideoAsset` class

### Step 4: Clean and Rebuild
1. Product → Clean Build Folder (`⇧⌘K`)
2. Product → Build (`⌘B`)

## What This Enables

After adding these attributes, the following code changes will work:

### FileScannerService.swift
- Extracts video dimensions from `AVAssetTrack.naturalSize`
- Stores width and height in Core Data

### MetadataView.swift
- Displays video resolution (e.g., "1920x1080", "3840x2160 (4K)")
- Shows resolution above Video Codec

## Note About Existing Data

Since these are new attributes with default values of `0`, existing video assets in the database will show "0x0" until they are re-scanned or the database is cleared and repopulated.

### To Re-Scan Existing Videos:
Option 1: Close and re-select the input folder (this will scan new files only)
Option 2: Delete the app's container to clear the database:
```bash
rm -rf ~/Library/Containers/com.yourcompany.VideoCullingApp
```
Then re-scan your video folders.

## Implementation Status

✅ FileScannerService.swift - Updated to extract dimensions
✅ MetadataView.swift - Updated to display resolution
⚠️ Core Data Model - Needs manual update in Xcode (instructions above)
