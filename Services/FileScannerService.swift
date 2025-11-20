//
//  FileScannerService.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData
import AVFoundation

class FileScannerService {

    static let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "mts"]
    nonisolated private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    @MainActor
    func scan(
        folderURL: URL,
        statusUpdate: @escaping @Sendable (String) -> Void,
        progressUpdate: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async {

        // 1. Get a list of all files recursively
        statusUpdate("Finding video files...")
        guard let fileURLs = getFileUrls(at: folderURL) else {
            statusUpdate("Error reading folder.")
            return
        }

        let videoURLs = fileURLs.filter { FileScannerService.videoExtensions.contains($0.pathExtension.lowercased()) }
        statusUpdate("Found \(videoURLs.count) videos. Analyzing...")

        // 2. Get a list of all file paths already in the database
        let existingPaths = await getExistingPaths(context: viewContext)

        // 3. Find only the *new* files
        let newURLs = videoURLs.filter { !existingPaths.contains($0.path) }

        if newURLs.isEmpty {
            statusUpdate("All \(videoURLs.count) videos are already in the database.")
            return
        }

        statusUpdate("Importing \(newURLs.count) new videos...")

        // 4. Process new files
        for (index, url) in newURLs.enumerated() {
            // Check for cancellation before processing each file
            if Task.isCancelled {
                statusUpdate("Scan cancelled by user.")
                return
            }

            let currentIndex = index + 1
            statusUpdate("Analyzing (\(currentIndex)/\(newURLs.count)): \(url.lastPathComponent)")
            progressUpdate?(currentIndex, newURLs.count, url.lastPathComponent)
            await createVideoAsset(from: url)
        }

        statusUpdate("Scan complete. Saving...")
        await saveContext()

        // Apply auto-mapped LUTs to all matching files (after scan is complete)
        statusUpdate("Applying LUTs to matching files...")
        await applyBatchLUTs()

        statusUpdate("Idle")
        progressUpdate?(0, 0, "")
    }
    
    private func getFileUrls(at directoryURL: URL) -> [URL]? {
        var fileURLs: [URL] = []
        let fileManager = FileManager.default
        let properties: [URLResourceKey] = [.isRegularFileKey]
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: properties,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    fileURLs.append(fileURL)
                }
            } catch {
                print("Error getting resource values for \(fileURL): \(error)")
            }
        }
        return fileURLs
    }
    
    private func getExistingPaths(context: NSManagedObjectContext) async -> Set<String> {
        var existingPaths = Set<String>()
        await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ManagedVideoAsset")
            fetchRequest.propertiesToFetch = ["filePath"]
            
            do {
                let results = try context.fetch(fetchRequest)
                for result in results {
                    if let path = result.value(forKey: "filePath") as? String {
                        existingPaths.insert(path)
                    }
                }
            } catch {
                print("Failed to fetch existing paths: \(error)")
            }
        }
        return existingPaths
    }
    
    private func createVideoAsset(from url: URL) async {
        let metadata = await extractMetadata(from: url)

        await viewContext.perform {
            let newAsset = ManagedVideoAsset(context: self.viewContext)
            newAsset.id = UUID()
            newAsset.filePath = url.path
            newAsset.fileName = url.lastPathComponent

            newAsset.fileSize = metadata.fileSize
            newAsset.duration = metadata.duration
            newAsset.frameRate = metadata.frameRate
            newAsset.bitrate = metadata.bitrate
            newAsset.creationDate = metadata.creationDate
            newAsset.lastEditDate = metadata.lastEditDate

            // Codec information
            newAsset.videoCodec = metadata.videoCodec
            newAsset.bitDepth = metadata.bitDepth
            newAsset.audioCodec = metadata.audioCodec
            newAsset.audioChannels = metadata.audioChannels
            newAsset.audioSampleRate = metadata.audioSampleRate

            // Video dimensions
            newAsset.videoWidth = metadata.videoWidth
            newAsset.videoHeight = metadata.videoHeight

            // Sony XML sidecar metadata
            newAsset.hasXMLSidecar = metadata.sonyMetadata.hasXMLSidecar
            newAsset.cameraManufacturer = metadata.sonyMetadata.cameraManufacturer
            newAsset.cameraModel = metadata.sonyMetadata.cameraModel
            newAsset.lensModel = metadata.sonyMetadata.lensModel
            newAsset.captureGamma = metadata.sonyMetadata.captureGamma
            newAsset.captureColorPrimaries = metadata.sonyMetadata.captureColorPrimaries
            newAsset.timecode = metadata.sonyMetadata.timecode
            newAsset.captureFps = metadata.sonyMetadata.captureFps

            // Set defaults BEFORE auto-mapping so auto-mapping can override them
            newAsset.userRating = 0
            newAsset.isFlaggedForDeletion = false
            newAsset.keywords = ""
            newAsset.newFileName = ""
            newAsset.trimStartTime = 0.0
            newAsset.trimEndTime = 0.0 // 0.0 means "end of clip"
            newAsset.selectedLUTId = ""
            newAsset.bakeInLUT = false

            // Auto-map LUT based on camera metadata (only if preference is enabled)
            if metadata.sonyMetadata.hasXMLSidecar {
                print("📹 Processing file with XML sidecar: \(url.lastPathComponent)")
                print("   Gamma: \(metadata.sonyMetadata.captureGamma)")
                print("   Color Space: \(metadata.sonyMetadata.captureColorPrimaries)")

                // Check if auto-apply preference is enabled
                let shouldAutoApply = UserPreferences.shared.applyDefaultLUTsToPreview
                print("   applyDefaultLUTsToPreview preference: \(shouldAutoApply)")

                if shouldAutoApply {
                    let availableLUTs = LUTManager.shared.availableLUTs
                    print("   Available LUTs count: \(availableLUTs.count)")

                    if let autoLUT = LUTAutoMapper.findBestLUT(
                        gamma: metadata.sonyMetadata.captureGamma,
                        colorSpace: metadata.sonyMetadata.captureColorPrimaries,
                        availableLUTs: availableLUTs
                    ) {
                        newAsset.selectedLUTId = autoLUT.id.uuidString
                        print("   ✅ Auto-selected LUT '\(autoLUT.name)' (ID: \(autoLUT.id.uuidString))")
                        print("   ✅ Saved to newAsset.selectedLUTId")
                    } else {
                        print("   ❌ No LUT auto-mapped")
                    }
                } else {
                    print("   ⚠️ Auto-apply LUTs is disabled in preferences, skipping auto-mapping")
                }
            } else {
                print("📹 Processing file WITHOUT XML sidecar: \(url.lastPathComponent)")
            }
        }
    }
    
    private func extractMetadata(from url: URL) async -> (
        fileSize: Int64,
        duration: Double,
        frameRate: Double,
        bitrate: Int64,
        creationDate: Date?,
        lastEditDate: Date?,
        videoCodec: String,
        bitDepth: String,
        audioCodec: String,
        audioChannels: String,
        audioSampleRate: Int32,
        videoWidth: Int32,
        videoHeight: Int32,
        sonyMetadata: SonyXMLMetadata
    ) {
        var fileSize: Int64 = 0
        var duration: Double = 0
        var frameRate: Double = 0
        var bitrate: Int64 = 0
        var creationDate: Date?
        var lastEditDate: Date?
        var videoCodec = "Unknown"
        var bitDepth = "Unknown"
        var audioCodec = "Unknown"
        var audioChannels = "Unknown"
        var audioSampleRate: Int32 = 0
        var videoWidth: Int32 = 0
        var videoHeight: Int32 = 0
        var sonyMetadata = SonyXMLMetadata()

        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = fileAttributes[.size] as? Int64 ?? 0
            creationDate = fileAttributes[.creationDate] as? Date
            lastEditDate = fileAttributes[.modificationDate] as? Date
        } catch {
            print("Failed to get file attributes: \(error)")
        }

        let asset = AVAsset(url: url)

        do {
            duration = try await asset.load(.duration).seconds

            // Extract video track information
            if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
                frameRate = Double(try await videoTrack.load(.nominalFrameRate))
                bitrate = Int64(try await videoTrack.load(.estimatedDataRate))

                // Get video dimensions
                let naturalSize = try await videoTrack.load(.naturalSize)
                videoWidth = Int32(naturalSize.width)
                videoHeight = Int32(naturalSize.height)

                // Get format descriptions for codec info
                if let formatDescriptions = try await videoTrack.load(.formatDescriptions) as? [CMFormatDescription],
                   let formatDesc = formatDescriptions.first {

                    // Get codec type
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
                    videoCodec = codecTypeToString(codecType)

                    // Try to extract bit depth from extensions
                    if let extensions = CMFormatDescriptionGetExtensions(formatDesc) as? [String: Any] {
                        if let depth = extensions["BitsPerComponent"] as? Int {
                            bitDepth = "\(depth)-bit"
                        } else if videoCodec.contains("265") || videoCodec.contains("HEVC") {
                            bitDepth = "10-bit (likely)" // HEVC often uses 10-bit
                        } else {
                            bitDepth = "8-bit (likely)"
                        }
                    }
                }
            }

            // Extract audio track information
            if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                if let formatDescriptions = try await audioTrack.load(.formatDescriptions) as? [CMFormatDescription],
                   let formatDesc = formatDescriptions.first {

                    // Get audio codec
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
                    audioCodec = audioCodecTypeToString(codecType)

                    // Get audio basic description
                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                        audioSampleRate = Int32(asbd.pointee.mSampleRate)
                        let channels = Int(asbd.pointee.mChannelsPerFrame)
                        audioChannels = channels == 1 ? "Mono" : channels == 2 ? "Stereo" : "\(channels) channels"
                    }
                }
            }
        } catch {
            print("Failed to load AVAsset metadata for \(url.lastPathComponent): \(error)")
        }

        // Look for Sony XML sidecar file
        if let xmlURL = SonyXMLParser.findXMLSidecar(for: url) {
            if let parsedMetadata = SonyXMLParser.parse(xmlURL: xmlURL) {
                sonyMetadata = parsedMetadata
            }
        }

        return (fileSize, duration, frameRate, bitrate, creationDate, lastEditDate,
                videoCodec, bitDepth, audioCodec, audioChannels, audioSampleRate,
                videoWidth, videoHeight, sonyMetadata)
    }

    // Helper to convert codec type to readable string
    private func codecTypeToString(_ codecType: CMVideoCodecType) -> String {
        switch codecType {
        case kCMVideoCodecType_H264:
            return "H.264/AVC"
        case kCMVideoCodecType_HEVC:
            return "H.265/HEVC"
        case kCMVideoCodecType_MPEG4Video:
            return "MPEG-4"
        case kCMVideoCodecType_MPEG2Video:
            return "MPEG-2"
        case kCMVideoCodecType_AppleProRes422:
            return "Apple ProRes 422"
        case kCMVideoCodecType_AppleProRes4444:
            return "Apple ProRes 4444"
        default:
            let fourCC = String(format: "%c%c%c%c",
                (codecType >> 24) & 0xFF,
                (codecType >> 16) & 0xFF,
                (codecType >> 8) & 0xFF,
                codecType & 0xFF)
            return "Unknown (\(fourCC))"
        }
    }

    private func audioCodecTypeToString(_ codecType: CMVideoCodecType) -> String {
        switch codecType {
        case kAudioFormatMPEG4AAC:
            return "AAC"
        case kAudioFormatAppleLossless:
            return "Apple Lossless (ALAC)"
        case kAudioFormatLinearPCM:
            return "PCM"
        case kAudioFormatAC3:
            return "AC-3"
        default:
            let fourCC = String(format: "%c%c%c%c",
                (codecType >> 24) & 0xFF,
                (codecType >> 16) & 0xFF,
                (codecType >> 8) & 0xFF,
                codecType & 0xFF)
            return "Unknown (\(fourCC))"
        }
    }
    
    private func saveContext() async {
        await viewContext.perform {
            do {
                try self.viewContext.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }

    // MARK: - LUT Auto-Application to Matching Files

    /// Applies LUTs to all files with matching gamma/colorSpace combinations in a batch after scanning
    private func applyBatchLUTs() async {
        await viewContext.perform {
            print("🎨 Starting batch LUT application to matching files...")

            // Fetch all video assets
            let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

            do {
                let allAssets = try self.viewContext.fetch(fetchRequest)

                // Group assets by their gamma/colorSpace combination
                var groups: [String: [ManagedVideoAsset]] = [:]

                for asset in allAssets {
                    guard let gamma = asset.captureGamma?.lowercased(),
                          let colorSpace = asset.captureColorPrimaries?.lowercased(),
                          !gamma.isEmpty, !colorSpace.isEmpty else {
                        continue
                    }

                    let normalizedGamma = self.normalizeForMatching(gamma)
                    let normalizedColorSpace = self.normalizeForMatching(colorSpace)
                    let key = "\(normalizedGamma)|\(normalizedColorSpace)"

                    if groups[key] == nil {
                        groups[key] = []
                    }
                    groups[key]?.append(asset)
                }

                // For each group, if any asset has a LUT, apply it to all assets in that group without a LUT
                var totalApplied = 0

                for (key, assets) in groups {
                    // Find the first asset with a LUT selected
                    guard let assetWithLUT = assets.first(where: { $0.selectedLUTId != nil && !($0.selectedLUTId?.isEmpty ?? true) }),
                          let lutId = assetWithLUT.selectedLUTId else {
                        continue
                    }

                    // Apply to all assets in this group that don't have a LUT
                    for asset in assets {
                        if asset.selectedLUTId == nil || asset.selectedLUTId?.isEmpty == true {
                            asset.selectedLUTId = lutId
                            totalApplied += 1
                            print("   ✅ Applied LUT to: \(asset.fileName ?? "unknown") (group: \(key))")
                        }
                    }
                }

                if totalApplied > 0 {
                    if self.viewContext.hasChanges {
                        try self.viewContext.save()
                        print("   🎉 Batch applied LUTs to \(totalApplied) file(s)")
                    }
                } else {
                    print("   ℹ️ No files needed LUT batch application")
                }
            } catch {
                print("   ❌ Failed to apply batch LUTs: \(error)")
            }
        }
    }

    /// Applies the same LUT to all other files with matching gamma/colorSpace but no LUT selected
    @available(*, deprecated, message: "Use applyBatchLUTs instead")
    private func applyLUTToMatchingFiles(gamma: String?, colorSpace: String?, lutId: String, lutName: String) {
        guard let gamma = gamma, let colorSpace = colorSpace else {
            return
        }

        print("🎨 Applying LUT '\(lutName)' to other files with Gamma: \(gamma), ColorSpace: \(colorSpace)")

        // Normalize gamma and colorSpace for matching (same logic as LUTAutoMapper)
        let normalizedGamma = normalizeForMatching(gamma.lowercased())
        let normalizedColorSpace = normalizeForMatching(colorSpace.lowercased())

        // Fetch all video assets that are already persisted (not newly created)
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")
        // Only fetch assets that have been previously saved (have permanent object IDs)
        fetchRequest.predicate = NSPredicate(format: "selectedLUTId == nil OR selectedLUTId == %@", "")

        do {
            let existingAssets = try viewContext.fetch(fetchRequest)
            var matchedCount = 0

            for asset in existingAssets {
                // Additional safety: Skip if object is a fault or has been deleted
                if asset.isFault || asset.isDeleted {
                    continue
                }

                // Skip if already has a LUT selected (double-check even though we have predicate)
                if let selectedLUTId = asset.selectedLUTId, !selectedLUTId.isEmpty {
                    continue
                }

                // Check if gamma and colorSpace match
                if let assetGamma = asset.captureGamma?.lowercased(),
                   let assetColorSpace = asset.captureColorPrimaries?.lowercased() {

                    let assetNormalizedGamma = normalizeForMatching(assetGamma)
                    let assetNormalizedColorSpace = normalizeForMatching(assetColorSpace)

                    if assetNormalizedGamma == normalizedGamma && assetNormalizedColorSpace == normalizedColorSpace {
                        asset.selectedLUTId = lutId
                        matchedCount += 1
                        print("   ✅ Applied LUT to: \(asset.fileName ?? "unknown")")
                    }
                }
            }

            if matchedCount > 0 {
                // Only save if we actually modified something
                if viewContext.hasChanges {
                    try viewContext.save()
                    print("   🎉 Applied LUT to \(matchedCount) matching file(s)")
                }
            } else {
                print("   ℹ️ No other matching files found to apply LUT")
            }
        } catch {
            print("   ❌ Failed to apply LUT to matching files: \(error)")
        }
    }

    /// Normalize string for matching by removing hyphens, dots, and spaces
    private func normalizeForMatching(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
