//
//  EditableFieldsView.swift
//  VideoCullingApp
//

import SwiftUI

struct EditableFieldsView: View {
    @ObservedObject var asset: ManagedVideoAsset
    @State private var displayFileName: String = ""
    @ObservedObject private var lutManager = LUTManager.shared
    @State private var selectedLUT: LUT?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // NAMING GROUP
            HStack(alignment: .center, spacing: 12) {
                Text("Re-Naming")
                    .font(.headline)
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                    .frame(width: 85, alignment: .leading)

                TextField("", text: $displayFileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(asset.isFlaggedForDeletion)
                    .onSubmit {
                        asset.newFileName = displayFileName
                        saveContext()
                    }
                    .onChange(of: displayFileName) { newValue in
                        asset.newFileName = newValue
                        saveContext()
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )

            // COLOR GROUP
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Color")
                        .font(.headline)
                        .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                        .frame(width: 85, alignment: .leading)

                    Picker("", selection: $selectedLUT) {
                        Text("No LUT Applied for Preview").tag(nil as LUT?)
                        ForEach(lutManager.availableLUTs) { lut in
                            Text(lut.name).tag(lut as LUT?)
                        }
                    }
                    .disabled(asset.isFlaggedForDeletion)
                    .onChange(of: selectedLUT) { newLUT in
                        asset.selectedLUTId = newLUT?.id.uuidString ?? ""
                        saveContext()
                    }

                    Spacer()
                }

                Toggle("Bake in LUT on Export", isOn: $asset.bakeInLUT)
                    .disabled(asset.isFlaggedForDeletion)
                    .onChange(of: asset.bakeInLUT) { _ in saveContext() }
                    .padding(.leading, 97) // Align with the picker
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )

            // RATING GROUP
            HStack(alignment: .center, spacing: 12) {
                Text("Rating")
                    .font(.headline)
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                    .frame(width: 85, alignment: .leading)

                StarRatingView(rating: $asset.userRating, showLabel: false, isDisabled: asset.isFlaggedForDeletion)
                    .onChange(of: asset.userRating) { _ in saveContext() }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )

            // KEYWORDS GROUP
            HStack(alignment: .center, spacing: 12) {
                Text("Keywords")
                    .font(.headline)
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                    .frame(width: 85, alignment: .leading)

                TextField("", text: asset.keywords_bind)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(asset.isFlaggedForDeletion)
                    .onSubmit(saveContext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            // Pre-populate with current filename (without extension) or newFileName if set
            if displayFileName.isEmpty {
                if let newName = asset.newFileName, !newName.isEmpty {
                    displayFileName = newName
                } else {
                    let currentName = asset.fileName ?? ""
                    let nameWithoutExtension = (currentName as NSString).deletingPathExtension
                    displayFileName = nameWithoutExtension
                }
            }

            // Load selected LUT
            if let lutId = asset.selectedLUTId, !lutId.isEmpty,
               let uuid = UUID(uuidString: lutId) {
                selectedLUT = lutManager.availableLUTs.first { $0.id == uuid }
            }
        }
        .onChange(of: asset.newFileName) { newValue in
            // Update displayFileName when newFileName changes externally (e.g., from naming convention)
            if let newName = newValue, !newName.isEmpty {
                displayFileName = newName
            }
        }
    }

    private func saveContext() {
        try? asset.managedObjectContext?.save()
    }
}
