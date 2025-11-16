//
//  LUTManagerView.swift
//  VideoCullingApp
//

import SwiftUI

struct LUTManagerView: View {
    @ObservedObject var lutManager: LUTManager
    @Environment(\.dismiss) var dismiss
    @State private var showingImportPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LUT Manager")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    showingImportPicker = true
                }) {
                    Label("Import LUT", systemImage: "plus.circle.fill")
                }

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // LUT List
            if lutManager.availableLUTs.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No LUTs Imported")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Import .cube or .3dl LUT files to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showingImportPicker = true
                    }) {
                        Label("Import LUT", systemImage: "plus.circle")
                    }
                    .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(lutManager.availableLUTs) { lut in
                        HStack {
                            Image(systemName: "circle.grid.3x3.fill")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(lut.name)
                                    .font(.body)
                                Text(lut.fileName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                lutManager.deleteLUT(lut)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    // Check if it's a LUT file
                    let ext = url.pathExtension.lowercased()
                    if ext == "cube" || ext == "3dl" {
                        // Request access to security-scoped resource
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer {
                            if accessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        let success = lutManager.importLUT(from: url)
                        if success {
                            print("Successfully imported LUT: \(url.lastPathComponent)")
                        } else {
                            print("Failed to import LUT: \(url.lastPathComponent)")
                        }
                    }
                }
            case .failure(let error):
                print("Failed to import LUT: \(error)")
            }
        }
    }
}
