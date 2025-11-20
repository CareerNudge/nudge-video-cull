# LUT Auto-Mapping Feature - Implementation Summary

## Overview

This feature automatically selects the appropriate default LUT for each video file based on its Sony camera metadata (gamma and color space information from XML sidecar files).

## How It Works

When a video file is scanned and has a Sony XML sidecar:

1. **Extract Metadata:** Parse gamma and color space from XML
2. **Match LUT:** Find the best matching default LUT using intelligent pattern matching
3. **Auto-Apply:** Automatically set the LUT for preview (per-file, not global)
4. **Visual Indicator:** Show auto-mapping status in the enriched metadata column

## Supported Mappings

### Sony Camera Profiles

| Camera Gamma | Color Space | Auto-Selected LUT | Output |
|--------------|-------------|-------------------|--------|
| S-Log3 | S-Gamut3.Cine | `SGamut3CineSLog3_To_LC-709.cube` | Rec.709 |
| S-Log3 | S-Gamut3 | `SGamut3CineSLog3_To_LC-709.cube` | Rec.709 |
| S-Log2 | S-Gamut | `SLog2SGumut_To_LC-709_.cube` | Rec.709 |

### Apple Camera Profiles

| Camera Gamma | Color Space | Auto-Selected LUT | Output |
|--------------|-------------|-------------------|--------|
| Apple Log | Rec.709 | `AppleLogToRec709-v1.0.cube` | Rec.709 |

### Fallback Behavior

- If gamma is detected but color space is missing, uses most common pairing
- S-Log3 (no color space) → Assumes S-Gamut3.Cine
- S-Log2 (no color space) → Assumes S-Gamut
- No matching LUT found → No auto-selection (user can manually choose)

## Available Default LUTs

Your DefaultLuts folder contains:

### Apple Log (2 LUTs)
- `AppleLogToLin-v1.0.cube` - Linear conversion
- `AppleLogToRec709-v1.0.cube` - Rec.709 conversion ⭐ Auto-selected

### S-Gamut/S-Log2 (4 LUTs)
- `From_SLog2SGumut_To_LC-709_.cube` ⭐ Auto-selected (primary)
- `From_SLog2SGumut_To_LC-709TypeA_.cube`
- `From_SLog2SGumut_To_Cine+709.cube`
- `From_SLog2SGumut_To_SLog2-709_.cube`

### S-Gamut3.Cine/S-Log3 (4 LUTs)
- `1_SGamut3CineSLog3_To_LC-709.cube` ⭐ Auto-selected (primary)
- `2_SGamut3CineSLog3_To_LC-709TypeA.cube`
- `3_SGamut3CineSLog3_To_SLog2-709.cube`
- `4_SGamut3CineSLog3_To_Cine+709.cube`

## Implementation Details

### Files Created

#### 1. LUTAutoMapper.swift (NEW)
**Location:** `Services/LUTAutoMapper.swift` ⚠️ **MUST BE ADDED TO XCODE PROJECT**

A smart mapping service with:
- **Pattern Matching:** Flexible gamma/color space pattern matching
- **Priority System:** Handles multiple matches with weighted priorities
- **Extensible:** Easy to add new camera profiles and mappings
- **Descriptive:** Provides user-friendly mapping descriptions

**Key Methods:**
```swift
static func findBestLUT(gamma: String?, colorSpace: String?, availableLUTs: [LUT]) -> LUT?
static func getMappingDescription(gamma: String?, colorSpace: String?) -> String
```

#### 2. FileScannerService.swift (UPDATED)
Auto-applies LUT during video scanning:
```swift
// Auto-map LUT based on camera metadata
if metadata.sonyMetadata.hasXMLSidecar {
    let availableLUTs = LUTManager.shared.availableLUTs
    if let autoLUT = LUTAutoMapper.findBestLUT(
        gamma: metadata.sonyMetadata.captureGamma,
        colorSpace: metadata.sonyMetadata.captureColorPrimaries,
        availableLUTs: availableLUTs
    ) {
        newAsset.selectedLUTId = autoLUT.id.uuidString
        print("Auto-selected LUT '\(autoLUT.name)' for \(url.lastPathComponent)")
    }
}
```

#### 3. EnrichedMetadataView.swift (UPDATED)
Shows auto-mapping status:
- Blue wand icon (✨) when LUT is auto-mapped
- Descriptive text: "Auto-mapped: S-Log3/S-Gamut3.Cine → Rec.709"
- Displayed below XML sidecar indicator

#### 4. LUTManager.swift (UPDATED)
Enhanced to support default LUTs:
- Loads LUTs from app bundle's `DefaultLuts` folder
- Differentiates between default and user-imported LUTs
- Prevents deletion of default LUTs
- Handles file paths correctly for both types

## User Experience

### Video with XML Sidecar (Auto-Mapping Available)

**Enriched Metadata Column shows:**
```
Camera Metadata
✅ XML Sidecar Available
✨ Auto-mapped: S-Log3/S-Gamut3.Cine → Rec.709

Camera: Sony ILCE-7CM2
Lens: 50mm F2 DG DN | Contemporary 02

Gamma: S-Log3
Color Space: S-Gamut3.Cine (S-Gamut3.Cine)
Capture FPS: 23.98p

Timecode: 01:23:45:12
```

The video will automatically preview with the LC-709 LUT applied.

### Video without XML Sidecar

**Enriched Metadata Column shows:**
```
Camera Metadata
❓ No XML Sidecar

Place a .XML file with the same name as your
video file to see enriched camera metadata.
```

No auto-mapping occurs. User can manually select a LUT if desired.

### Manual Override

Users can always manually change the LUT selection in the editable fields section, overriding the auto-mapped choice.

## Setup Requirements

### 1. Add LUTAutoMapper.swift to Xcode
See `XCODE_MANUAL_STEPS.md` for detailed instructions.

### 2. Add DefaultLuts Folder as Folder Reference
**CRITICAL:** Must be added as "folder reference" (blue folder), NOT a group:
- Right-click project → Add Files
- Select DefaultLuts folder
- Choose "Create folder references"
- Ensure VideoCullingApp target is checked

This preserves the folder structure in the app bundle.

### 3. Rebuild
- Product → Clean Build Folder (⇧⌘K)
- Product → Build (⌘B)

## Testing Checklist

After setup:

- [ ] Build succeeds without errors
- [ ] App launches successfully
- [ ] LUT Manager shows default LUTs with `[Default]` prefix
- [ ] Default LUTs cannot be deleted
- [ ] Scan a folder with Sony videos + XML sidecars
- [ ] Videos with S-Log3/S-Gamut3.Cine auto-select LC-709 LUT
- [ ] Videos with S-Log2/S-Gamut auto-select SLog2 → LC-709 LUT
- [ ] Enriched metadata shows auto-mapping indicator (✨)
- [ ] Video preview applies the selected LUT correctly
- [ ] Manually changing LUT works and overrides auto-selection

## Extending the Mappings

To add support for new camera profiles:

1. Add LUT files to `DefaultLuts` folder (organized by camera/profile)
2. Update `lutMappings` array in `LUTAutoMapper.swift`:

```swift
let lutMappings: [(gammaPattern: String, colorPattern: String, lutPattern: String, priority: Int)] = [
    // Add new mapping here
    ("newgamma", "newcolorspace", "NewLUTFileName.cube", 10),

    // Existing mappings...
    ("slog3", "sgamut3.cine", "SGamut3CineSLog3_To_LC-709.cube", 10),
]
```

3. Update `getMappingDescription()` for user-friendly display text

## Technical Notes

### Why Per-File Auto-Selection?

Each video file can have different camera settings (gamma, color space). Auto-mapping is applied **per file** rather than globally, ensuring each clip gets the correct LUT regardless of how the user shot different scenes.

### LUT Priority System

When multiple LUTs match, the priority system ensures the most appropriate one is chosen:
- Priority 10: Exact gamma + color space match
- Priority 9: Partial match with common pairings
- Priority 5: Generic gamma match (no color space specified)

### Default vs User LUTs

- **Default LUTs:** Stored in app bundle, read-only, prefixed with `[Default]`
- **User LUTs:** Stored in Application Support, can be deleted, no prefix
- Both types available for manual selection
- Only default LUTs used for auto-mapping (consistent behavior)

## Future Enhancements

Potential improvements:

- Support for more camera manufacturers (Panasonic V-Log, RED, ARRI)
- Multiple LUT presets per gamma/color space combination
- User-configurable auto-mapping preferences
- LUT preview thumbnails in picker
- Batch re-map if default LUTs are updated
