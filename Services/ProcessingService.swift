//
//  ProcessingService.swift
//  VideoCullingApp
//
//  Native AVFoundation-based video processing service
//  App Store compatible - no FFmpeg dependencies
//

import SwiftUI
import CoreData
import AVFoundation
import CoreImage

class ProcessingService {

    nonisolated private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    @MainActor
    func processChanges(
        testMode: Bool = false,
        outputFolderURL: URL? = nil,
        statusUpdate: @escaping @Sendable (String) -> Void,
        progressUpdate: @escaping @Sendable (Int, Int, String) -> Void = { _, _, _ in }
    ) async {
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

        if testMode {
            // Test Mode: Only process files with actual video processing needed
            fetchRequest.predicate = NSPredicate(
                format: "trimStartTime > 0 OR trimEndTime > 0 OR (bakeInLUT == YES AND selectedLUTId != %@)",
                ""
            )
        } else {
            // Normal Mode: Process ALL files (copy to output, apply changes, delete flagged)
            // No predicate filter - process everything
            fetchRequest.predicate = nil
        }

        var assetsToProcess: [ManagedVideoAsset] = []
        do {
            assetsToProcess = try viewContext.fetch(fetchRequest)
        } catch {
            statusUpdate("Error fetching assets to process.")
            return
        }

        if assetsToProcess.isEmpty {
            statusUpdate(testMode ? "No videos to export in test mode." : "No changes to apply.")
            return
        }

        // Create output folder if it doesn't exist
        var outputFolder: URL?
        if let providedOutputURL = outputFolderURL {
            outputFolder = providedOutputURL
        } else if testMode, let firstAsset = assetsToProcess.first,
                  let firstFileURL = firstAsset.fileURL {
            let parentFolder = firstFileURL.deletingLastPathComponent()
            outputFolder = parentFolder.appendingPathComponent("Culled", isDirectory: true)
        }

        if let outputURL = outputFolder {
            do {
                try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                statusUpdate(testMode ? "Created output folder for test exports..." : "Created output folder...")
            } catch {
                statusUpdate("Error: Could not create output folder: \(error.localizedDescription)")
                return
            }
        }

        // --- 1. Deletion Phase (Only when processing in-place, not in test mode) ---
        // Only delete files if we're working in-place (no separate output folder)
        let isDifferentOutputFolder = outputFolder != nil
        if !testMode && !isDifferentOutputFolder {
            let assetsToDelete = assetsToProcess.filter { $0.isFlaggedForDeletion }
            if !assetsToDelete.isEmpty {
                statusUpdate("Deleting \(assetsToDelete.count) files...")
                for asset in assetsToDelete {
                    await delete(asset: asset)
                }
            }
        } else if isDifferentOutputFolder {
            // When outputting to different folder, simply don't copy flagged files
            let assetsToSkip = assetsToProcess.filter { $0.isFlaggedForDeletion }
            if !assetsToSkip.isEmpty {
                statusUpdate("Skipping \(assetsToSkip.count) flagged files (not copying to output)...")
            }
        }

        // --- 2. Processing Phase ---
        // Filter out flagged files - they've either been deleted or won't be copied
        let assetsToModify = assetsToProcess.filter { !$0.isFlaggedForDeletion }
        let totalToProcess = assetsToModify.count

        for (index, asset) in assetsToModify.enumerated() {
            // Check for cancellation before processing each file
            if Task.isCancelled {
                statusUpdate("Processing cancelled by user.")
                return
            }

            let currentIndex = index + 1
            let statusPrefix = "(\(currentIndex)/\(totalToProcess))"

            // Extract Core Data properties safely before any await calls
            let (fileName, fileURL, trimStart, trimEnd, bakeLUT, lutId, newFileName) = await viewContext.perform {
                (
                    asset.fileName ?? "file",
                    asset.fileURL,
                    asset.trimStartTime,
                    asset.trimEndTime,
                    asset.bakeInLUT,
                    asset.selectedLUTId ?? "",
                    asset.newFileName ?? ""
                )
            }

            var currentPath = fileURL

            // Update progress
            progressUpdate(currentIndex, totalToProcess, fileName)

            // Check if trimming or LUT baking is needed
            let isTrimmed = trimStart > 0.001 || (trimEnd > 0 && trimEnd < 0.999)
            let shouldBakeLUT = bakeLUT && !lutId.isEmpty
            let needsVideoProcessing = isTrimmed || shouldBakeLUT

            if needsVideoProcessing, let path = currentPath {
                statusUpdate("\(statusPrefix) Processing: \(fileName)")

                do {
                    if let newPath = try await processVideo(
                        asset: asset,
                        currentURL: path,
                        trim: isTrimmed,
                        bakeLUT: shouldBakeLUT,
                        testMode: testMode,
                        outputFolder: outputFolder
                    ) {
                        currentPath = newPath
                        // Update Core Data property safely
                        await viewContext.perform {
                            asset.filePath = newPath.path
                        }
                    } else {
                        statusUpdate("\(statusPrefix) Failed to process \(fileName)")
                        continue
                    }
                } catch {
                    statusUpdate("\(statusPrefix) Error: \(error.localizedDescription)")
                    continue
                }
            } else if !needsVideoProcessing, let outputFolder = outputFolder, let path = currentPath {
                // No video processing needed, but we have an output folder - copy the file
                statusUpdate("\(statusPrefix) Copying: \(fileName)")
                do {
                    // Determine destination filename (use new name if set, otherwise original)
                    let destinationFileName: String
                    if !testMode, !newFileName.isEmpty {
                        let fileExtension = path.pathExtension
                        destinationFileName = newFileName.hasSuffix(".\(fileExtension)") ? newFileName : "\(newFileName).\(fileExtension)"
                    } else {
                        destinationFileName = path.lastPathComponent
                    }

                    let destinationURL = outputFolder.appendingPathComponent(destinationFileName)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: path, to: destinationURL)
                    currentPath = destinationURL

                    // Update Core Data properties safely
                    await viewContext.perform {
                        asset.filePath = destinationURL.path
                        asset.fileName = destinationFileName
                        asset.newFileName = "" // Clear the newFileName after applying
                    }
                } catch {
                    statusUpdate("\(statusPrefix) Error copying: \(error.localizedDescription)")
                    continue
                }
            }

            // B. Renaming (Only when processing in-place without output folder)
            if !testMode, outputFolder == nil, let path = currentPath {
                let needsRename = !newFileName.isEmpty
                if needsRename {
                    statusUpdate("\(statusPrefix) Renaming: \(fileName)")
                    if let renamedPath = await runRename(asset: asset, currentURL: path) {
                        // Update Core Data properties safely
                        await viewContext.perform {
                            asset.filePath = renamedPath.path
                            asset.fileName = renamedPath.lastPathComponent
                            asset.newFileName = ""
                        }
                    } else {
                        statusUpdate("\(statusPrefix) Failed to rename")
                    }
                }
            }
        }

        await saveContext()
        statusUpdate(testMode ? "Test export complete!" : "Processing complete!")
    }

    /// Process only specific selected assets
    @MainActor
    func processSelectedAssets(
        _ assets: [ManagedVideoAsset],
        outputFolderURL: URL,
        statusUpdate: @escaping @Sendable (String) -> Void,
        progressUpdate: @escaping @Sendable (Int, Int, String) -> Void = { _, _, _ in }
    ) async {
        if assets.isEmpty {
            statusUpdate("No assets selected to export.")
            return
        }

        // Create output folder if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)
            statusUpdate("Created output folder for selected exports...")
        } catch {
            statusUpdate("Error: Could not create output folder: \(error.localizedDescription)")
            return
        }

        // Filter out flagged files
        let assetsToModify = assets.filter { !$0.isFlaggedForDeletion }
        let totalToProcess = assetsToModify.count

        if totalToProcess == 0 {
            statusUpdate("All selected files are flagged for deletion. Nothing to export.")
            return
        }

        statusUpdate("Exporting \(totalToProcess) selected file\(totalToProcess == 1 ? "" : "s")...")

        for (index, asset) in assetsToModify.enumerated() {
            // Check for cancellation before processing each file
            if Task.isCancelled {
                statusUpdate("Processing cancelled by user.")
                return
            }

            let currentIndex = index + 1
            let statusPrefix = "(\(currentIndex)/\(totalToProcess))"

            // Extract Core Data properties safely before any await calls
            let (fileName, fileURL, trimStart, trimEnd, bakeLUT, lutId, newFileName) = await viewContext.perform {
                (
                    asset.fileName ?? "file",
                    asset.fileURL,
                    asset.trimStartTime,
                    asset.trimEndTime,
                    asset.bakeInLUT,
                    asset.selectedLUTId ?? "",
                    asset.newFileName ?? ""
                )
            }

            var currentPath = fileURL

            // Update progress
            progressUpdate(currentIndex, totalToProcess, fileName)

            // Check if trimming or LUT baking is needed
            let isTrimmed = trimStart > 0.001 || (trimEnd > 0 && trimEnd < 0.999)
            let shouldBakeLUT = bakeLUT && !lutId.isEmpty
            let needsVideoProcessing = isTrimmed || shouldBakeLUT

            if needsVideoProcessing, let path = currentPath {
                statusUpdate("\(statusPrefix) Processing: \(fileName)")

                do {
                    if let newPath = try await processVideo(
                        asset: asset,
                        currentURL: path,
                        trim: isTrimmed,
                        bakeLUT: shouldBakeLUT,
                        testMode: false,
                        outputFolder: outputFolderURL
                    ) {
                        currentPath = newPath
                    } else {
                        statusUpdate("\(statusPrefix) Error processing \(fileName)")
                    }
                } catch {
                    statusUpdate("\(statusPrefix) Error: \(error.localizedDescription)")
                }
            } else if let path = currentPath {
                // No processing needed, just copy to output folder
                statusUpdate("\(statusPrefix) Copying: \(fileName)")

                let finalFileName = !newFileName.isEmpty ? newFileName + ".\(path.pathExtension)" : path.lastPathComponent
                let destinationURL = outputFolderURL.appendingPathComponent(finalFileName)

                do {
                    // Copy file to output
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: path, to: destinationURL)
                    currentPath = destinationURL
                } catch {
                    statusUpdate("\(statusPrefix) Copy failed: \(error.localizedDescription)")
                }
            }

            // Apply renaming if needed (only if outputting to same folder as source)
            if !newFileName.isEmpty, let finalPath = currentPath {
                statusUpdate("\(statusPrefix) Renaming: \(fileName)")

                let newName = "\(newFileName).\(finalPath.pathExtension)"
                let newURL = finalPath.deletingLastPathComponent().appendingPathComponent(newName)

                do {
                    // Check if target name already exists
                    if FileManager.default.fileExists(atPath: newURL.path) {
                        // Remove existing file
                        try FileManager.default.removeItem(at: newURL)
                    }
                    try FileManager.default.moveItem(at: finalPath, to: newURL)
                } catch {
                    statusUpdate("\(statusPrefix) Rename failed: \(error.localizedDescription)")
                }
            }
        }

        await saveContext()
        statusUpdate("Export of selected files complete!")
    }

    // MARK: - AVFoundation Video Processing

    private func processVideo(
        asset: ManagedVideoAsset,
        currentURL: URL,
        trim: Bool,
        bakeLUT: Bool,
        testMode: Bool = false,
        outputFolder: URL? = nil
    ) async throws -> URL? {

        guard let sourceURL = currentURL as URL? else {
            throw NSError(domain: "App", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source file not found."])
        }

        let avAsset = AVAsset(url: sourceURL)

        // --- 1. Calculate Time Range ---
        let duration = try await avAsset.load(.duration)
        let startTime = CMTime(seconds: asset.trimStartTime * duration.seconds, preferredTimescale: duration.timescale)
        let endTimeValue = (asset.trimEndTime > 0 && asset.trimEndTime < 0.999) ? asset.trimEndTime : 1.0
        let endTime = CMTime(seconds: endTimeValue * duration.seconds, preferredTimescale: duration.timescale)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        // --- 2. Get Source Video Properties for Quality Preservation ---
        let videoProperties = try await getVideoProperties(from: avAsset)
        print("📹 Source video: \(videoProperties.codec) | \(Int(videoProperties.width))x\(Int(videoProperties.height)) | \(String(format: "%.2f", videoProperties.frameRate)) fps | \(String(format: "%.1f", videoProperties.bitrate / 1_000_000)) Mbps")

        // --- 3. Determine Export Preset ---
        let hasFilter = bakeLUT && !(asset.selectedLUTId ?? "").isEmpty && asset.bakeInLUT

        // Choose preset based on source resolution and codec to preserve quality
        let preset: String
        if hasFilter {
            // When baking LUT, choose resolution-appropriate preset to better preserve codec
            let width = videoProperties.width
            let height = videoProperties.height
            let isHEVC = videoProperties.codec == "hvc1" || videoProperties.codec == "hev1"

            if width >= 3840 || height >= 2160 {
                // 4K or higher
                preset = isHEVC ? AVAssetExportPresetHEVC3840x2160 : AVAssetExportPreset3840x2160
            } else if width >= 1920 || height >= 1080 {
                // 1080p
                preset = isHEVC ? AVAssetExportPresetHEVC1920x1080 : AVAssetExportPreset1920x1080
            } else {
                // 720p or lower
                preset = AVAssetExportPresetHighestQuality
            }

            print("⚙️ Selected preset: \(preset) (resolution: \(Int(width))x\(Int(height)), codec: \(videoProperties.codec))")
        } else {
            preset = AVAssetExportPresetPassthrough
        }

        // --- 4. Create Export Session ---
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: preset) else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetExportSession."])
        }

        // --- 4. Configure Output ---
        let tempOutputURL: URL
        if let outputFolder = outputFolder {
            // Output to specified folder (both test and normal mode with output folder)
            // Determine output filename (use new name if set, otherwise original)
            let outputFileName: String
            if !testMode, let newName = asset.newFileName, !newName.isEmpty {
                let fileExtension = sourceURL.pathExtension
                outputFileName = newName.hasSuffix(".\(fileExtension)") ? newName : "\(newName).\(fileExtension)"
            } else {
                outputFileName = sourceURL.lastPathComponent
            }
            tempOutputURL = outputFolder.appendingPathComponent(outputFileName)
        } else {
            // No output folder: Use temp directory for in-place replacement
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileName = "processed_\(UUID().uuidString).\(sourceURL.pathExtension)"
            tempOutputURL = tempDir.appendingPathComponent(tempFileName)
        }

        exportSession.outputURL = tempOutputURL
        exportSession.outputFileType = try await avAsset.determineBestExportFileType()
        exportSession.timeRange = timeRange

        // --- 5. Configure Quality Settings for Re-encoding ---
        if hasFilter {
            // Set metadata to preserve as much info as possible
            exportSession.metadata = try await avAsset.load(.metadata)

            print("⚙️ Export mode: Re-encoding with LUT")
        } else {
            print("⚙️ Export mode: Lossless passthrough")
        }

        // --- 6. Add Video Composition for LUT ---
        if hasFilter {
            if let lutId = asset.selectedLUTId,
               !lutId.isEmpty,
               let uuid = UUID(uuidString: lutId),
               let lut = LUTManager.shared.availableLUTs.first(where: { $0.id == uuid }) {

                let lutURL = LUTManager.shared.getLUTFileURL(for: lut)

                do {
                    let lutData = try LUTParser.parse(lutURL: lutURL)
                    exportSession.videoComposition = try await createLUTComposition(
                        for: avAsset,
                        lutData: lutData
                    )
                } catch {
                    print("⚠️ Warning: Failed to create LUT composition: \(error)")
                    print("⚠️ Continuing export without LUT baking")
                    // Don't throw - continue export without LUT
                }
            }
        }

        // --- 6. Run Export ---
        await exportSession.export()

        // --- 7. Handle Result ---
        switch exportSession.status {
        case .completed:
            // Verify output exists
            guard FileManager.default.fileExists(atPath: tempOutputURL.path) else {
                throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export completed but file not found"])
            }

            // Validate output quality
            await validateExportQuality(
                sourceProperties: videoProperties,
                outputURL: tempOutputURL,
                wasReencoded: hasFilter
            )

            if outputFolder != nil {
                // Output folder specified: File is already in output folder
                // Update asset metadata
                asset.filePath = tempOutputURL.path
                asset.fileName = tempOutputURL.lastPathComponent

                // Reset asset state after successful export
                asset.trimStartTime = 0.0
                asset.trimEndTime = 0.0
                asset.newFileName = "" // Clear newFileName after applying
                if bakeLUT {
                    asset.selectedLUTId = ""
                    asset.bakeInLUT = false
                }
                return tempOutputURL
            } else {
                // No output folder: Replace original file in place
                let backupURL = sourceURL.deletingLastPathComponent()
                    .appendingPathComponent("backup_\(sourceURL.lastPathComponent)")

                // Move original to backup
                try FileManager.default.moveItem(at: sourceURL, to: backupURL)

                // Move processed file to original location
                try FileManager.default.moveItem(at: tempOutputURL, to: sourceURL)

                // Delete backup on success
                try? FileManager.default.removeItem(at: backupURL)

                // Reset asset state
                asset.trimStartTime = 0.0
                asset.trimEndTime = 0.0
                if bakeLUT {
                    asset.selectedLUTId = ""
                    asset.bakeInLUT = false
                }

                return sourceURL
            }

        case .failed:
            let error = exportSession.error ?? NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"])
            throw error

        case .cancelled:
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"])

        default:
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export in unexpected state: \(exportSession.status.rawValue)"])
        }
    }

    // MARK: - Video Quality Helpers

    private struct VideoProperties {
        let codec: String
        let width: CGFloat
        let height: CGFloat
        let frameRate: Float
        let bitrate: Double
    }

    private func getVideoProperties(from asset: AVAsset) async throws -> VideoProperties {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)

        // Detect codec from format descriptions
        var codecName = "Unknown"
        if let formatDescriptions = try? await videoTrack.load(.formatDescriptions) as? [CMFormatDescription],
           let formatDescription = formatDescriptions.first {
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            codecName = fourCharCodeToString(codecType)
        }

        return VideoProperties(
            codec: codecName,
            width: naturalSize.width,
            height: naturalSize.height,
            frameRate: nominalFrameRate,
            bitrate: Double(estimatedDataRate)
        )
    }

    private func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "Unknown"
    }

    private func validateExportQuality(
        sourceProperties: VideoProperties,
        outputURL: URL,
        wasReencoded: Bool
    ) async {
        do {
            let outputAsset = AVAsset(url: outputURL)
            let outputProperties = try await getVideoProperties(from: outputAsset)

            print("\n✅ Export completed:")
            print("   Source: \(sourceProperties.codec) | \(Int(sourceProperties.width))x\(Int(sourceProperties.height)) | \(String(format: "%.2f", sourceProperties.frameRate)) fps | \(String(format: "%.1f", sourceProperties.bitrate / 1_000_000)) Mbps")
            print("   Output: \(outputProperties.codec) | \(Int(outputProperties.width))x\(Int(outputProperties.height)) | \(String(format: "%.2f", outputProperties.frameRate)) fps | \(String(format: "%.1f", outputProperties.bitrate / 1_000_000)) Mbps")

            // Validate dimensions
            if abs(outputProperties.width - sourceProperties.width) > 1 ||
               abs(outputProperties.height - sourceProperties.height) > 1 {
                print("   ⚠️ WARNING: Dimensions changed!")
            } else {
                print("   ✓ Dimensions preserved")
            }

            // Validate frame rate
            if abs(outputProperties.frameRate - sourceProperties.frameRate) > 0.1 {
                print("   ⚠️ WARNING: Frame rate changed!")
            } else {
                print("   ✓ Frame rate preserved")
            }

            // Codec and bitrate notes
            if wasReencoded {
                print("   ℹ️ Re-encoded with LUT (codec may differ from source)")

                // Check if bitrate dropped significantly
                let bitrateRatio = outputProperties.bitrate / sourceProperties.bitrate
                if bitrateRatio < 0.7 {
                    print("   ⚠️ WARNING: Output bitrate is \(Int(bitrateRatio * 100))% of source")
                    print("      Consider using higher quality source files or check AVAssetExportPresetHighestQuality settings")
                } else {
                    print("   ✓ Bitrate maintained at \(Int(bitrateRatio * 100))% of source")
                }
            } else {
                print("   ✓ Lossless passthrough (100% quality preserved)")
            }

            print("")

        } catch {
            print("⚠️ Could not validate output quality: \(error.localizedDescription)")
        }
    }

    // MARK: - LUT Video Composition

    private func createLUTComposition(for asset: AVAsset, lutData: LUTData) async throws -> AVVideoComposition {

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        _ = try await videoTrack.load(.preferredTransform)

        // Read and preserve source frame rate
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let sourceFrameRate = nominalFrameRate > 0 ? nominalFrameRate : 30.0

        // Calculate frame duration from source frame rate
        // For precise frame rates like 23.976, use appropriate timescale
        let frameDuration: CMTime
        if abs(sourceFrameRate - 23.976) < 0.01 {
            // 23.976 fps = 24000/1001
            frameDuration = CMTime(value: 1001, timescale: 24000)
        } else if abs(sourceFrameRate - 29.97) < 0.01 {
            // 29.97 fps = 30000/1001
            frameDuration = CMTime(value: 1001, timescale: 30000)
        } else if abs(sourceFrameRate - 59.94) < 0.01 {
            // 59.94 fps = 60000/1001
            frameDuration = CMTime(value: 1001, timescale: 60000)
        } else {
            // Use direct frame rate (24, 25, 30, 60, 120, etc.)
            let timescale = Int32(sourceFrameRate * 1000)
            frameDuration = CMTime(value: 1000, timescale: timescale)
        }

        print("📹 Preserving source frame rate: \(sourceFrameRate) fps")

        // Create the color cube filter
        guard let filter = LUTParser.createColorCubeFilter(from: lutData) else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create color cube filter"])
        }

        // Create video composition
        let composition = AVMutableVideoComposition(asset: asset) { [filter] request in
            let source = request.sourceImage.clampedToExtent()
            filter.setValue(source, forKey: kCIInputImageKey)

            let output = filter.outputImage ?? source
            request.finish(with: output, context: nil)
        }

        composition.renderSize = naturalSize
        composition.frameDuration = frameDuration

        return composition
    }

    // MARK: - File Operations

    private func delete(asset: ManagedVideoAsset) async {
        guard let fileURL = asset.fileURL else {
            print("Cannot delete asset with no file URL")
            return
        }

        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            viewContext.delete(asset)
        } catch {
            print("Failed to delete file: \(error)")
        }
    }

    private func runRename(asset: ManagedVideoAsset, currentURL: URL) async -> URL? {
        guard let newName = asset.newFileName, !newName.isEmpty else {
            return currentURL
        }

        let fileExtension = currentURL.pathExtension
        var finalNewName = newName

        if !finalNewName.hasSuffix(".\(fileExtension)") {
            finalNewName += ".\(fileExtension)"
        }

        let newURL = currentURL.deletingLastPathComponent()
            .appendingPathComponent(finalNewName)

        if FileManager.default.fileExists(atPath: newURL.path) {
            print("Cannot rename: File already exists at \(newURL.path)")
            return nil
        }

        do {
            try FileManager.default.moveItem(at: currentURL, to: newURL)
            return newURL
        } catch {
            print("Failed to rename file: \(error)")
            return nil
        }
    }

    private func saveContext() async {
        await viewContext.perform {
            do {
                try self.viewContext.save()
            } catch {
                print("Failed to save context after processing: \(error)")
            }
        }
    }
}

// MARK: - AVAsset Extensions

extension AVAsset {
    func determineBestExportFileType() async throws -> AVFileType {
        // Try to determine the file type from the asset
        if let url = (self as? AVURLAsset)?.url {
            let ext = url.pathExtension.lowercased()

            switch ext {
            case "mov":
                return .mov
            case "mp4", "m4v":
                return .mp4
            case "m4a":
                return .m4a
            default:
                break
            }
        }

        // Check if the asset has video tracks
        let videoTracks = try await self.loadTracks(withMediaType: .video)
        if !videoTracks.isEmpty {
            return .mov // Default to MOV for video
        }

        // Audio only
        return .m4a
    }
}
