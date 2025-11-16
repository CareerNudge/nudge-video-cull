//
//  EditableFieldsView.swift
//  VideoCullingApp
//

import SwiftUI

struct EditableFieldsView: View {
    @ObservedObject var asset: ManagedVideoAsset
    @State private var displayFileName: String = ""
    @StateObject private var lutManager = LUTManager.shared
    @State private var selectedLUT: LUT?

    var body: some View {
        Form {
            // 1. Editable File Name (pre-populated with current filename without extension)
            TextField("Rename:", text: $displayFileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    asset.newFileName = displayFileName
                    saveContext()
                }
                .onChange(of: displayFileName) { newValue in
                    asset.newFileName = newValue
                    saveContext()
                }

            // 2. Flag for Deletion
            Toggle("Flag for Deletion", isOn: $asset.isFlaggedForDeletion)
                .tint(.red)
                .onChange(of: asset.isFlaggedForDeletion) { _ in saveContext() }

            // 3. Star Rating (Custom View)
            StarRatingView(rating: $asset.userRating)
                .onChange(of: asset.userRating) { _ in saveContext() }

            // 4. Keywords
            TextField("Keywords:", text: asset.keywords_bind)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(saveContext)

            Divider()

            // 5. LUT Preview Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("LUT Preview:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedLUT) {
                    Text("None").tag(nil as LUT?)
                    ForEach(lutManager.availableLUTs) { lut in
                        Text(lut.name).tag(lut as LUT?)
                    }
                }
                .frame(maxWidth: .infinity)
                .onChange(of: selectedLUT) { newLUT in
                    asset.selectedLUTId = newLUT?.id.uuidString ?? ""
                    saveContext()
                }
            }

            // 6. Bake in LUT Toggle
            Toggle("Bake in LUT on Export", isOn: $asset.bakeInLUT)
                .onChange(of: asset.bakeInLUT) { _ in saveContext() }
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
