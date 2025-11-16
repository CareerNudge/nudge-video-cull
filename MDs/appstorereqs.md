# Nudge Video Cull - App Store Migration & Feature Update

## 1. Project Goal

The primary goal of this task is to modify the existing "Nudge Video Cull" macOS application to meet all technical requirements for distribution on the Mac App Store.

This includes:
1.  **Replacing** the FFmpeg dependency with a native `AVFoundation` export pipeline.
2.  **Adding** a new feature for previewing and "baking in" (exporting) video files with `.cube` LUTs.
3.  **Implementing** app sandboxing and privacy requirements.
4.  **Integrating** a paid subscription model using StoreKit 2.

**Subscription Model:** 1-month free trial, followed by a $2.99/month auto-renewable subscription.

---

## 2. CRITICAL: App Store Rejection Fixes

These changes are mandatory. Failure to implement them will result in an immediate rejection from the Apple App Review team.

### A. Replace FFmpeg with a Native AVFoundation Export Pipeline

**Problem:** The FFmpeg dependency and its GPL/LGPL license are incompatible with the App Store.
**Solution:** We will replace all trimming and export logic with a robust, native `AVFoundation` pipeline. This pipeline must intelligently decide whether to perform a **lossless passthrough** (for simple trims) or a **full re-encode** (when a LUT is applied).

**File to Modify:** `Services/ProcessingService.swift`

1.  Remove all `Process` API calls or references to an `ffmpeg` binary.
2.  Refactor the export logic in `ProcessingService` to be smarter. It must differentiate between two export paths:
    * **Path 1: Lossless Trim.** If the user *only* sets trim points and does *not* apply a LUT, use `AVAssetExportPresetPassthrough`. This is a stream copy, it's fast, and it does not re-encode.
    * **Path 2: Filtered Export.** If the user applies a LUT (or any other visual filter), the video *must* be re-encoded. Use `AVAssetExportPresetHighestQuality`.

3.  Implement the `processChanges` logic as follows:

```swift
// In Services/ProcessingService.swift

import AVFoundation
import CoreImage // We need this for the filter logic

// ... inside the ProcessingService class ...

// This function will be called from your "Apply Changes" button loop
@MainActor
func processVideo(asset: ManagedVideoAsset) async throws {
    guard let sourceURL = asset.fileURL else {
        throw NSError(domain: "App", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source file not found."])
    }
    
    let avAsset = AVAsset(url: sourceURL)
    
    // --- 1. Get User's Export Settings ---
    
    // Calculate the time range for trimming
    let duration = try await avAsset.load(.duration)
    let startTime = CMTime(seconds: asset.trimStartTime * duration.seconds, preferredTimescale: duration.timescale)
    let endTimeValue = (asset.trimEndTime > 0 && asset.trimEndTime < 0.999) ? asset.trimEndTime : 1.0
    let endTime = CMTime(seconds: endTimeValue * duration.seconds, preferredTimescale: duration.timescale)
    let timeRange = CMTimeRange(start: startTime, end: endTime)
    
    // Check if user ONLY trimmed
    let isSimpleTrim = timeRange.duration < duration && asset.selectedLutURL == nil // We will add `selectedLutURL`
    // Check if user applied a filter
    let hasFilter = asset.selectedLutURL != nil // (or other filters)
    
    // --- 2. Create the Export Session ---
    
    let preset: String
    if isSimpleTrim {
        // Path 1: Lossless Passthrough
        preset = AVAssetExportPresetPassthrough
    } else {
        // Path 2: Re-encode
        preset = AVAssetExportPresetHighestQuality
    }
    
    guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: preset) else {
        throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetExportSession."])
    }
    
    // --- 3. Configure the Session ---
    
    // Create a temporary output URL
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
    let outputFileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
    let outputURL = tempDir.appendingPathComponent(outputFileName)
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = try avAsset.determineBestExportFileType()
    exportSession.timeRange = timeRange
    
    // --- 4. (CRITICAL) Add Video Composition if Filtering ---
    if hasFilter {
        // This composition will be built using the logic from Section 3
        // We will add `asset.selectedLutURL` and `asset.selectedLutDimension`
        // to the Core Data model.
        let lutData = try LutParser.parse(lutURL: asset.selectedLutURL) 
        let lutDimension = asset.selectedLutDimension
        
        exportSession.videoComposition = createLutComposition(
            for: avAsset, 
            lutData: lutData, 
            lutDimension: lutDimension
        )
    }
    
    // --- 5. Run the Export ---
    await exportSession.export()
    
    // --- 6. Handle Success/Failure ---
    if exportSession.status == .completed {
        // Succeeded: Replace the original file
        // (This logic needs to be robust: trash original, move new file)
        print("Export complete. Replacing \(sourceURL.path) with \(outputURL.path)")
        try fileManager.trashItem(at: sourceURL, resultingItemURL: nil)
        try fileManager.moveItem(at: outputURL, to: sourceURL)
        
        // Reset the asset's "dirty" state in Core Data
        asset.trimStartTime = 0.0
        asset.trimEndTime = 0.0
        asset.selectedLutURL = nil
    } else if let error = exportSession.error {
        throw error
    } else {
        throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error."])
    }
}

// Helper to determine file type for passthrough
extension AVAsset {
    func determineBestExportFileType() throws -> AVFileType {
        // (Implementation for this helper is in the previous response)
        // ...
        return .mov // Fallback
    }
}