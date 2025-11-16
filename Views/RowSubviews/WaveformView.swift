//
//  WaveformView.swift
//  VideoCullingApp
//

import SwiftUI
import AVFoundation
import Accelerate

struct WaveformView: View {
    let asset: ManagedVideoAsset
    @Binding var trimStart: Double
    @Binding var trimEnd: Double

    @State private var waveformSamples: [Float] = []
    @State private var isGenerating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.1))

                // Waveform bars
                HStack(spacing: 1) {
                    ForEach(0..<waveformSamples.count, id: \.self) { index in
                        let normalizedStart = Double(index) / Double(waveformSamples.count)
                        let normalizedEnd = Double(index + 1) / Double(waveformSamples.count)

                        // Check if this bar overlaps with the trim range
                        let isInRange = normalizedEnd > trimStart && normalizedStart < trimEnd

                        Rectangle()
                            .fill(isInRange ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3))
                            .frame(width: max(1, geometry.size.width / CGFloat(waveformSamples.count)))
                            .frame(height: CGFloat(waveformSamples[index]) * geometry.size.height)
                    }
                }
                .frame(height: geometry.size.height, alignment: .center)
            }
        }
        .frame(height: 40)
        .cornerRadius(4)
        .onAppear {
            generateWaveform()
        }
    }

    private func generateWaveform() {
        guard !isGenerating else { return }
        guard let url = asset.fileURL else { return }

        isGenerating = true

        Task {
            let samples = await extractAudioSamples(from: url, targetSampleCount: 100)
            await MainActor.run {
                self.waveformSamples = samples
                self.isGenerating = false
            }
        }
    }

    private func extractAudioSamples(from url: URL, targetSampleCount: Int) async -> [Float] {
        let avAsset = AVAsset(url: url)

        guard let audioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first else {
            return Array(repeating: 0.0, count: targetSampleCount)
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: avAsset)
        } catch {
            print("Failed to create asset reader: \(error)")
            return Array(repeating: 0.0, count: targetSampleCount)
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            print("Failed to start reading")
            return Array(repeating: 0.0, count: targetSampleCount)
        }

        var allSamples: [Float] = []

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)

            data.withUnsafeMutableBytes { rawBufferPointer in
                if let baseAddress = rawBufferPointer.baseAddress {
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
                }
            }

            // Convert Int16 samples to Float
            let int16Samples = data.withUnsafeBytes { $0.bindMemory(to: Int16.self) }
            let floatSamples = int16Samples.map { Float($0) / Float(Int16.max) }
            allSamples.append(contentsOf: floatSamples)
        }

        // Downsample to target count
        guard !allSamples.isEmpty else {
            return Array(repeating: 0.0, count: targetSampleCount)
        }

        let samplesPerBucket = max(1, allSamples.count / targetSampleCount)
        var downsampled: [Float] = []

        for i in 0..<targetSampleCount {
            let startIndex = i * samplesPerBucket
            let endIndex = min(startIndex + samplesPerBucket, allSamples.count)

            if startIndex < allSamples.count {
                let bucket = allSamples[startIndex..<endIndex]
                let rms = sqrt(bucket.map { $0 * $0 }.reduce(0, +) / Float(bucket.count))
                downsampled.append(abs(rms))
            } else {
                downsampled.append(0.0)
            }
        }

        // Normalize
        if let maxSample = downsampled.max(), maxSample > 0 {
            downsampled = downsampled.map { $0 / maxSample }
        }

        return downsampled
    }
}
