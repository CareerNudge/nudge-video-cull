//
//  EnrichedMetadataView.swift
//  VideoCullingApp
//

import SwiftUI

struct EnrichedMetadataView: View {
    @ObservedObject var asset: ManagedVideoAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Camera Metadata")
                .font(.headline)
                .foregroundColor(.primary)

            if asset.hasXMLSidecar {
                // XML Sidecar indicator
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("XML Sidecar Available")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding(.bottom, 4)

                // LUT Auto-mapping indicator
                if !(asset.selectedLUTId?.isEmpty ?? true) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(LUTAutoMapper.getMappingDescription(
                            gamma: asset.captureGamma,
                            colorSpace: asset.captureColorPrimaries
                        ))
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    }
                    .padding(.bottom, 4)
                }

                Divider().padding(.vertical, 2)

                // Camera Information
                if !(asset.cameraManufacturer?.isEmpty ?? true) || !(asset.cameraModel?.isEmpty ?? true) {
                    MetadataRow(
                        label: "Camera",
                        value: formatCamera(manufacturer: asset.cameraManufacturer, model: asset.cameraModel)
                    )
                    .font(.subheadline)
                }

                // Lens Information
                if !(asset.lensModel?.isEmpty ?? true) {
                    MetadataRow(label: "Lens", value: asset.lensModel ?? "")
                        .font(.subheadline)
                }

                Divider().padding(.vertical, 2)

                // Picture Profile Information
                if !(asset.captureGamma?.isEmpty ?? true) {
                    MetadataRow(label: "Gamma", value: formatGamma(asset.captureGamma))
                        .font(.subheadline)
                }

                if !(asset.captureColorPrimaries?.isEmpty ?? true) {
                    MetadataRow(label: "Color Space", value: formatColorSpace(asset.captureColorPrimaries))
                        .font(.subheadline)
                }

                // Capture FPS from XML (may differ from file metadata)
                if !(asset.captureFps?.isEmpty ?? true) {
                    MetadataRow(label: "Capture FPS", value: asset.captureFps ?? "")
                        .font(.subheadline)
                }

                Divider().padding(.vertical, 2)

                // Timecode Information
                if !(asset.timecode?.isEmpty ?? true) {
                    MetadataRow(label: "Timecode", value: asset.timecode ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            } else {
                // No XML sidecar found
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill.badge.questionmark")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("No XML Sidecar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Place a .XML file with the same name as your video file to see enriched camera metadata.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
    }

    // MARK: - Formatters

    private func formatCamera(manufacturer: String?, model: String?) -> String {
        let mfg = manufacturer ?? ""
        let mdl = model ?? ""

        if !mfg.isEmpty && !mdl.isEmpty {
            return "\(mfg) \(mdl)"
        } else if !mdl.isEmpty {
            return mdl
        } else if !mfg.isEmpty {
            return mfg
        } else {
            return "Unknown"
        }
    }

    private func formatGamma(_ gamma: String?) -> String {
        guard let gamma = gamma else { return "Unknown" }

        // Add user-friendly names for common gamma curves
        switch gamma.lowercased() {
        case "rec709", "rec.709":
            return "Rec.709 (Standard)"
        case "slog2":
            return "S-Log2"
        case "slog3":
            return "S-Log3"
        case "hlg", "hlg1", "hlg2", "hlg3":
            return "HLG (Hybrid Log-Gamma)"
        case "cine1":
            return "Cine1"
        case "cine2":
            return "Cine2"
        case "cine3":
            return "Cine3"
        case "cine4":
            return "Cine4"
        default:
            return gamma
        }
    }

    private func formatColorSpace(_ colorSpace: String?) -> String {
        guard let colorSpace = colorSpace else { return "Unknown" }

        // Add user-friendly names for common color spaces
        switch colorSpace.lowercased() {
        case "rec709", "rec.709":
            return "Rec.709 (BT.709)"
        case "rec2020", "rec.2020":
            return "Rec.2020 (BT.2020)"
        case "sgamut", "s-gamut":
            return "S-Gamut"
        case "sgamut3", "s-gamut3":
            return "S-Gamut3"
        case "sgamut3.cine", "s-gamut3.cine":
            return "S-Gamut3.Cine"
        case "dci-p3":
            return "DCI-P3"
        default:
            return colorSpace
        }
    }
}
