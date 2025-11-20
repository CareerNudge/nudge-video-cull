# Sony XML Sidecar Metadata Feature - Implementation Summary

## Overview

This feature adds support for parsing Sony camera .XML sidecar files to display enriched professional metadata in a new second metadata column in the video gallery view.

## What Was Implemented

### 1. Core Data Schema Updates
**File:** `VideoCullingApp.xcdatamodeld/VideoCullingApp.xcdatamodel/contents`

Added the following attributes to `ManagedVideoAsset` entity:
- `cameraManufacturer` (String) - e.g., "Sony"
- `cameraModel` (String) - e.g., "ILCE-7CM2"
- `lensModel` (String) - e.g., "50mm F2 DG DN | Contemporary 02"
- `captureGamma` (String) - e.g., "rec709", "S-Log3"
- `captureColorPrimaries` (String) - e.g., "rec709", "S-Gamut3.Cine"
- `timecode` (String) - e.g., "01:23:45:12"
- `captureFps` (String) - e.g., "23.98p", "24p"
- `hasXMLSidecar` (Boolean) - Indicates if XML sidecar was found

### 2. SonyXMLParser Service
**File:** `Services/SonyXMLParser.swift` ⚠️ **MUST BE ADDED TO XCODE PROJECT**

A comprehensive XML parser that:
- Finds .XML sidecar files with matching video filenames
- Parses Sony's NonRealTimeMeta XML format
- Extracts professional metadata including:
  - Camera device information
  - Lens model
  - Picture profile settings (Gamma, Color Space)
  - Timecode information
  - Capture frame rate
- Supports both `.XML` and `.xml` extensions

**Key Methods:**
```swift
static func findXMLSidecar(for videoURL: URL) -> URL?
static func parse(xmlURL: URL) -> SonyXMLMetadata?
```

### 3. FileScannerService Updates
**File:** `Services/FileScannerService.swift`

Updated to:
- Look for XML sidecar files during video scanning
- Parse XML metadata if sidecar found
- Store enriched metadata in Core Data alongside video file metadata

### 4. EnrichedMetadataView - Second Metadata Column
**File:** `Views/RowSubviews/EnrichedMetadataView.swift` ⚠️ **MUST BE ADDED TO XCODE PROJECT**

A new SwiftUI view that displays:
- **XML Sidecar Status Indicator:**
  - Green checkmark if XML found
  - Gray question mark if no XML
- **Camera Information:**
  - Manufacturer + Model (e.g., "Sony ILCE-7CM2")
  - Lens Model
- **Picture Profile:**
  - Gamma with user-friendly names (e.g., "Rec.709 (Standard)", "S-Log3")
  - Color Space with expanded names (e.g., "Rec.709 (BT.709)")
  - Capture FPS from XML
- **Timecode:** Formatted as HH:MM:SS:FF
- **Helpful message** when no XML sidecar is available

**Supported Gamma Profiles:**
- Rec.709 (Standard)
- S-Log2, S-Log3
- HLG (Hybrid Log-Gamma)
- Cine1, Cine2, Cine3, Cine4

**Supported Color Spaces:**
- Rec.709 (BT.709)
- Rec.2020 (BT.2020)
- S-Gamut, S-Gamut3, S-Gamut3.Cine
- DCI-P3

### 5. VideoAssetRowView Layout Updates
**File:** `Views/VideoAssetRowView.swift`

Updated to include 4 columns:
1. **Player & Trimmer** (400px)
2. **Editable Fields** (350px max)
3. **File Metadata** (200px) - Standard video file metadata
4. **Enriched Camera Metadata** (200px) - Sony XML metadata ⭐ NEW

Total row width: ~1200px (with spacing and padding)

### 6. ContentView Window Updates
**File:** `Views/ContentView.swift`

Updated minimum window width from 1200 to 1400 pixels to accommodate the wider rows.

## File Naming Convention

For the XML sidecar to be recognized:
- **Video File:** `C0001.MP4`
- **Sidecar File:** `C0001.XML` (or `C0001.xml`)

The base filename must match exactly. The parser checks for both uppercase and lowercase `.XML`/`.xml` extensions.

## Sample XML Structure Supported

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.20">
    <LtcChangeTable tcFps="24" halfStep="false">
        <LtcChange frameCount="0" value="16162602" status="increment"/>
    </LtcChangeTable>
    <VideoFormat>
        <VideoFrame captureFps="23.98p"/>
    </VideoFormat>
    <Device manufacturer="Sony" modelName="ILCE-7CM2"/>
    <Lens modelName="50mm F2 DG DN | Contemporary 02"/>
    <AcquisitionRecord>
        <Group name="CameraUnitMetadataSet">
            <Item name="CaptureGammaEquation" value="rec709"/>
            <Item name="CaptureColorPrimaries" value="rec709"/>
        </Group>
    </AcquisitionRecord>
</NonRealTimeMeta>
```

## Build Status

⚠️ **ACTION REQUIRED**: The following files must be manually added to the Xcode project:

1. `Services/SonyXMLParser.swift`
2. `Views/RowSubviews/EnrichedMetadataView.swift`

See `XCODE_MANUAL_STEPS.md` for detailed instructions.

## Testing Checklist

After adding the required files to Xcode:

- [ ] Build succeeds (Product → Build)
- [ ] App launches without crashes
- [ ] Select a folder containing video files
- [ ] Videos without XML sidecars show "No XML Sidecar" message
- [ ] Add a `.XML` file with matching video filename
- [ ] Re-scan the folder (close and re-open)
- [ ] Verify XML sidecar indicator shows green checkmark
- [ ] Verify camera metadata displays correctly:
  - [ ] Camera manufacturer and model
  - [ ] Lens model
  - [ ] Gamma (with friendly name)
  - [ ] Color space (with friendly name)
  - [ ] Capture FPS
  - [ ] Timecode (formatted)

## Known Limitations

1. **Existing Videos:** Videos already in the database will not have XML metadata until the folder is re-scanned (close and re-open the folder)

2. **XML Format Support:** Currently only supports Sony's NonRealTimeMeta XML format. Other camera manufacturers' XML formats would require additional parser implementations.

3. **Manual File Addition:** The SonyXMLParser and EnrichedMetadataView files must be manually added to the Xcode project as they cannot be programmatically added to the project file.

## Future Enhancements

Potential improvements for this feature:

- Support for other camera manufacturers' XML/metadata formats (Canon, Panasonic, RED, ARRI)
- Ability to edit/override XML metadata
- Export XML metadata to FCPXML
- Batch XML metadata import
- XML metadata search/filter in gallery
