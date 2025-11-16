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

    private var viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    @MainActor
    func processChanges(testMode: Bool = false, outputFolderURL: URL? = nil, statusUpdate: @escaping (String) -> Void) async {
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

        // --- 1. Deletion Phase (Skip in Test Mode) ---
        if !testMode {
            let assetsToDelete = assetsToProcess.filter { $0.isFlaggedForDeletion }
            if !assetsToDelete.isEmpty {
                statusUpdate("Deleting \(assetsToDelete.count) files...")
                for asset in assetsToDelete {
                    await delete(asset: asset)
                }
            }
        }

        // --- 2. Processing Phase ---
        let assetsToModify = assetsToProcess.filter { !$0.isFlaggedForDeletion }

        for (index, asset) in assetsToModify.enumerated() {
            let statusPrefix = "(\(index + 1)/\(assetsToModify.count))"
            var currentPath = asset.fileURL

            // Check if trimming or LUT baking is needed
            let isTrimmed = asset.trimStartTime > 0.001 || (asset.trimEndTime > 0 && asset.trimEndTime < 0.999)
            let shouldBakeLUT = asset.bakeInLUT && !(asset.selectedLUTId ?? "").isEmpty
            let needsVideoProcessing = isTrimmed || shouldBakeLUT

            if needsVideoProcessing, let path = currentPath {
                statusUpdate("\(statusPrefix) Processing: \(asset.fileName ?? "file")")

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
                        asset.filePath = newPath.path
                    } else {
                        statusUpdate("\(statusPrefix) Failed to process \(asset.fileName ?? "file")")
                        continue
                    }
                } catch {
                    statusUpdate("\(statusPrefix) Error: \(error.localizedDescription)")
                    continue
                }
            } else if !needsVideoProcessing, let outputFolder = outputFolder, let path = currentPath {
                // No video processing needed, but we have an output folder - copy the file
                statusUpdate("\(statusPrefix) Copying: \(asset.fileName ?? "file")")
                do {
                    let destinationURL = outputFolder.appendingPathComponent(path.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: path, to: destinationURL)
                    currentPath = destinationURL
                    asset.filePath = destinationURL.path
                } catch {
                    statusUpdate("\(statusPrefix) Error copying: \(error.localizedDescription)")
                    continue
                }
            }

            // B. Renaming (Skip in Test Mode)
            if !testMode, let path = currentPath {
                let needsRename = !(asset.newFileName ?? "").isEmpty
                if needsRename {
                    statusUpdate("\(statusPrefix) Renaming: \(asset.fileName ?? "file")")
                    if let renamedPath = await runRename(asset: asset, currentURL: path) {
                        asset.filePath = renamedPath.path
                        asset.fileName = renamedPath.lastPathComponent
                        asset.newFileName = ""
                    } else {
                        statusUpdate("\(statusPrefix) Failed to rename")
                    }
                }
            }
        }

        await saveContext()
        statusUpdate(testMode ? "Test export complete!" : "Processing complete!")
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

        // --- 2. Determine Export Preset ---
        let hasFilter = bakeLUT && !(asset.selectedLUTId ?? "").isEmpty
        let preset: String = hasFilter ? AVAssetExportPresetHighestQuality : AVAssetExportPresetPassthrough

        // --- 3. Create Export Session ---
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: preset) else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetExportSession."])
        }

        // --- 4. Configure Output ---
        let tempOutputURL: URL
        if let outputFolder = outputFolder {
            // Output to specified folder (both test and normal mode with output folder)
            tempOutputURL = outputFolder.appendingPathComponent(sourceURL.lastPathComponent)
        } else {
            // No output folder: Use temp directory for in-place replacement
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileName = "processed_\(UUID().uuidString).\(sourceURL.pathExtension)"
            tempOutputURL = tempDir.appendingPathComponent(tempFileName)
        }

        exportSession.outputURL = tempOutputURL
        exportSession.outputFileType = try await avAsset.determineBestExportFileType()
        exportSession.timeRange = timeRange

        // --- 5. Add Video Composition for LUT ---
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
                    print("Failed to create LUT composition: \(error)")
                    throw error
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

            if outputFolder != nil {
                // Output folder specified: File is already in output folder
                // Reset asset state after successful export
                asset.trimStartTime = 0.0
                asset.trimEndTime = 0.0
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

    // MARK: - LUT Video Composition

    private func createLUTComposition(for asset: AVAsset, lutData: LUTData) async throws -> AVVideoComposition {

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        _ = try await videoTrack.load(.preferredTransform)

        // Create the color cube filter
        guard let filter = LUTParser.createColorCubeFilter(from: lutData) else {
            throw NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create color cube filter"])
        }

        // Create video composition
        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            filter.setValue(source, forKey: kCIInputImageKey)

            let output = filter.outputImage ?? source
            request.finish(with: output, context: nil)
        }

        composition.renderSize = naturalSize
        composition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps

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
