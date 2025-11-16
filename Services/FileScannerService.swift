//
//  FileScannerService.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData
import AVFoundation

class FileScannerService {
    
    static let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "mts"]
    private var viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    @MainActor
    func scan(
        folderURL: URL,
        statusUpdate: @escaping (String) -> Void
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
            statusUpdate("Analyzing (\(index + 1)/\(newURLs.count)): \(url.lastPathComponent)")
            await createVideoAsset(from: url)
        }
        
        statusUpdate("Scan complete. Saving...")
        await saveContext()
        statusUpdate("Idle")
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

            // Set defaults
            newAsset.userRating = 0
            newAsset.isFlaggedForDeletion = false
            newAsset.keywords = ""
            newAsset.newFileName = ""
            newAsset.trimStartTime = 0.0
            newAsset.trimEndTime = 0.0 // 0.0 means "end of clip"
            newAsset.selectedLUTId = ""
            newAsset.bakeInLUT = false
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
        audioSampleRate: Int32
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

        return (fileSize, duration, frameRate, bitrate, creationDate, lastEditDate,
                videoCodec, bitDepth, audioCodec, audioChannels, audioSampleRate)
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
}
