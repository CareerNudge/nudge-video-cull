//
//  EditableFieldsView.swift
//  VideoCullingApp
//

import SwiftUI

struct EditableFieldsView: View {
    @ObservedObject var asset: ManagedVideoAsset
    var viewModel: ContentViewModel  // Not @ObservedObject to avoid type-checker complexity
    @State private var displayFileName: String = ""
    @State private var keywords: String = ""
    @ObservedObject private var lutManager = LUTManager.shared
    @State private var selectedLUT: LUT?
    @State private var justLearnedMapping: Bool = false
    @State private var learnedLUTName: String = ""
    @State private var alsoApplyBakingToMatchingFiles: Bool = false
    @State private var showApplyToAllPrompt: Bool = false

    private var selectedAssetsCount: Int {
        viewModel.selectedAssets.count
    }

    private var hasMultipleSelection: Bool {
        selectedAssetsCount > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top-align all content

            // Multi-selection indicator
            if hasMultipleSelection {
                HStack {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundColor(.blue)
                    Text("\(selectedAssetsCount) videos selected")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                    Button("Clear Selection") {
                        viewModel.clearSelection()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
            }

            // NAMING GROUP
            HStack(alignment: .center, spacing: 12) {
                Text("Re-Naming")
                    .font(.headline)
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                    .frame(width: 85, alignment: .leading)

                TextField("", text: $displayFileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(asset.isFlaggedForDeletion)
                    .onChange(of: selectedLUT) { newLUT in
                        asset.selectedLUTId = newLUT?.id.uuidString ?? ""
                        saveContext()

                        // If multiple assets are selected, apply to all of them
                        if hasMultipleSelection {
                            applyToSelectedAssets { selectedAsset in
                                selectedAsset.selectedLUTId = newLUT?.id.uuidString ?? ""
                            }
                            print("✅ Applied LUT '\(newLUT?.name ?? "none")' to \(selectedAssetsCount) selected videos")
                        }

                        print("🔍 LUT selection changed in EditableFieldsView")
                        print("   Selected LUT: \(newLUT?.name ?? "nil")")
                        print("   Asset: \(asset.fileName ?? "unknown")")
                        print("   Asset gamma: \(asset.captureGamma ?? "nil")")
                        print("   Asset colorSpace: \(asset.captureColorPrimaries ?? "nil")")

                        // Always apply to matching files when user manually selects a LUT (only if NOT multi-selecting)
                        if !hasMultipleSelection,
                           let selectedLUT = newLUT,
                           let gamma = asset.captureGamma, !gamma.isEmpty,
                           let colorSpace = asset.captureColorPrimaries, !colorSpace.isEmpty {

                            print("   ✅ Has gamma and colorSpace, applying to matching files...")

                            // Learn the preference (only if auto-apply setting is enabled)
                            if UserPreferences.shared.applyDefaultLUTsToPreview {
                                // Check if user already has a learned preference for this combo
                                let existingPreference = lutManager.getUserPreferredLUT(gamma: gamma, colorSpace: colorSpace)
                                print("   Existing user preference: \(existingPreference?.name ?? "none")")

                                // Only learn if user is selecting a DIFFERENT LUT than their current preference
                                if existingPreference?.id != selectedLUT.id {
                                    print("   💡 Learning new user preference...")
                                    let learned = lutManager.learnLUTPreference(
                                        gamma: gamma,
                                        colorSpace: colorSpace,
                                        selectedLUT: selectedLUT
                                    )

                                    if learned {
                                        print("   ✅ Preference learned")
                                        justLearnedMapping = true
                                        learnedLUTName = selectedLUT.name
                                    }
                                }
                            }

                            // ALWAYS apply to matching files (regardless of preference setting)
                            print("   🔄 Applying LUT to all matching files...")
                            applyLearnedLUTToMatchingFiles()
                        } else if !hasMultipleSelection {
                            print("   ❌ Missing gamma, colorSpace, or LUT not selected")
                        }
                    }
                }

                Toggle("Bake in LUT on Export", isOn: $asset.bakeInLUT)
                    .disabled(asset.isFlaggedForDeletion)
                    .onChange(of: asset.bakeInLUT) { newValue in
                        saveContext()

                        // If multiple assets are selected, apply to all of them
                        if hasMultipleSelection {
                            applyToSelectedAssets { selectedAsset in
                                selectedAsset.bakeInLUT = newValue
                            }
                            print("✅ Applied 'Bake in LUT' (\(newValue)) to \(selectedAssetsCount) selected videos")
                        }

                        // Show prompt when baking is enabled (only if NOT multi-selecting)
                        if newValue && !hasMultipleSelection {
                            showApplyToAllPrompt = true
                        } else {
                            showApplyToAllPrompt = false
                        }
                    }
                    .padding(.leading, 97) // Align with the picker

                // Prompt: Apply baking to all matching gamma/colorSpace files
                if showApplyToAllPrompt && asset.bakeInLUT {
                    let hasMetadata = asset.captureGamma != nil && !asset.captureGamma!.isEmpty &&
                                     asset.captureColorPrimaries != nil && !asset.captureColorPrimaries!.isEmpty
                    let hasLUT = selectedLUT != nil
                    let canApply = hasMetadata && hasLUT

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Apply this to all videos with this Gamma/Color-Space?")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        if hasMetadata, let gamma = asset.captureGamma, let colorSpace = asset.captureColorPrimaries {
                            Text("Gamma: \(gamma) | Color Space: \(colorSpace)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("⚠️ This video has no camera metadata (requires Sony XML sidecar)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        HStack(spacing: 12) {
                            Button("Yes") {
                                if canApply {
                                    applyBakingToMatchingFiles()
                                }
                                showApplyToAllPrompt = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                            .disabled(!canApply)

                            Button("No") {
                                showApplyToAllPrompt = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.leading, 97)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: showApplyToAllPrompt)
                }

                // Learning notification (shown when user selects a LUT for unmapped gamma/colorSpace)
                if justLearnedMapping {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✓ Applied \(learnedLUTName) to matching \(asset.captureColorPrimaries ?? "unknown") / \(asset.captureGamma ?? "unknown") videos (without existing LUT)")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Undo this preference") {
                            // Undo the learning preference
                            lutManager.forgetLUTPreference(
                                gamma: asset.captureGamma,
                                colorSpace: asset.captureColorPrimaries
                            )
                            justLearnedMapping = false
                        }
                        .buttonStyle(.link)
                        .foregroundColor(.blue)
                    }
                    .padding(.leading, 97)
                    .padding(.top, 8)
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

            // RATING GROUP
            HStack(alignment: .center, spacing: 12) {
                Text("Rating")
                    .font(.headline)
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                    .frame(width: 85, alignment: .leading)

                StarRatingView(rating: $asset.userRating, showLabel: false, isDisabled: asset.isFlaggedForDeletion)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: asset.userRating) { newValue in
                        saveContext()

                        // If multiple assets are selected, apply to all of them
                        if hasMultipleSelection {
                            applyToSelectedAssets { selectedAsset in
                                selectedAsset.userRating = newValue
                            }
                            print("✅ Applied rating \(newValue) to \(selectedAssetsCount) selected videos")
                        }
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

            // KEYWORDS GROUP (Expandable)
            HStack(alignment: .top, spacing: 12) {
                Text("Keywords")
                    .font(.headline)
                    .foregroundColor(asset.isFlaggedForDeletion ? .secondary : .primary)
                    .frame(width: 85, alignment: .leading)

                TextEditor(text: $keywords)
                    .font(.body)
                    .disabled(asset.isFlaggedForDeletion)
                    .frame(maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: keywords) { newValue in
                        asset.keywords = newValue
                        saveContext()

                        // If multiple assets are selected, apply to all of them
                        if hasMultipleSelection {
                            applyToSelectedAssets { selectedAsset in
                                selectedAsset.keywords = newValue
                            }
                            print("✅ Applied keywords to \(selectedAssetsCount) selected videos")
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )

            Spacer(minLength: 0) // Push content to top
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

            // Pre-populate keywords
            if keywords.isEmpty {
                keywords = asset.keywords ?? ""
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
        .task(id: asset.id) {
            // Reload all fields when asset changes (e.g., switching videos)
            // task(id:) is more reliable than onChange for parameter changes

            // Reload LUT selection
            if let lutId = asset.selectedLUTId, !lutId.isEmpty,
               let uuid = UUID(uuidString: lutId) {
                selectedLUT = lutManager.availableLUTs.first { $0.id == uuid }
            } else {
                selectedLUT = nil
            }

            // Reload filename
            if let newName = asset.newFileName, !newName.isEmpty {
                displayFileName = newName
            } else {
                let currentName = asset.fileName ?? ""
                let nameWithoutExtension = (currentName as NSString).deletingPathExtension
                displayFileName = nameWithoutExtension
            }

            // Reload keywords
            keywords = asset.keywords ?? ""
        }
    }

    private func saveContext() {
        try? asset.managedObjectContext?.save()
    }

    // MARK: - Multi-Selection Batch Operations

    private func applyToSelectedAssets(operation: (ManagedVideoAsset) -> Void) {
        guard let context = asset.managedObjectContext else { return }

        for objectID in viewModel.selectedAssets {
            if let selectedAsset = try? context.existingObject(with: objectID) as? ManagedVideoAsset {
                selectedAsset.objectWillChange.send()
                operation(selectedAsset)
            }
        }

        try? context.save()
        context.processPendingChanges()
    }

    private func applyLearnedLUTToMatchingFiles() {
        guard let gamma = asset.captureGamma,
              let colorSpace = asset.captureColorPrimaries,
              let lutId = asset.selectedLUTId,
              !gamma.isEmpty,
              !colorSpace.isEmpty,
              !lutId.isEmpty else {
            print("⚠️ Cannot apply learned LUT: missing gamma, colorSpace, or lutId")
            return
        }

        // Normalize the current asset's gamma and colorSpace for matching
        let normalizedGamma = normalizeForMatching(gamma.lowercased())
        let normalizedColorSpace = normalizeForMatching(colorSpace.lowercased())

        // Fetch all assets from Core Data
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

        do {
            guard let context = asset.managedObjectContext else {
                print("❌ No managed object context available")
                return
            }

            let allAssets = try context.fetch(fetchRequest)

            // Filter to matching gamma/colorSpace (excluding the current asset)
            // ONLY apply to files that don't already have a LUT selected
            let matchingAssets = allAssets.filter { otherAsset in
                guard otherAsset != asset else { return false }

                guard let otherGamma = otherAsset.captureGamma,
                      let otherColorSpace = otherAsset.captureColorPrimaries else {
                    return false
                }

                // Normalize for comparison (remove hyphens, dots, spaces)
                let otherNormalizedGamma = normalizeForMatching(otherGamma.lowercased())
                let otherNormalizedColorSpace = normalizeForMatching(otherColorSpace.lowercased())

                // Check if gamma and colorSpace match (using normalized values)
                let gammaMatches = otherNormalizedGamma == normalizedGamma
                let colorSpaceMatches = otherNormalizedColorSpace == normalizedColorSpace

                // Only include if no LUT is already selected
                let hasNoLUT = otherAsset.selectedLUTId == nil || otherAsset.selectedLUTId?.isEmpty == true

                if gammaMatches && colorSpaceMatches {
                    print("   🔍 Checking: \(otherAsset.fileName ?? "unknown")")
                    print("      Gamma: \(otherGamma) -> \(otherNormalizedGamma) (matches: \(gammaMatches))")
                    print("      ColorSpace: \(otherColorSpace) -> \(otherNormalizedColorSpace) (matches: \(colorSpaceMatches))")
                    print("      Has LUT already: \(!hasNoLUT) (\(otherAsset.selectedLUTId ?? "nil"))")
                }

                return gammaMatches && colorSpaceMatches && hasNoLUT
            }

            print("🔄 Applying learned LUT to \(matchingAssets.count) matching files (without existing LUT)")
            print("   Source Gamma: \(gamma) -> \(normalizedGamma)")
            print("   Source Color Space: \(colorSpace) -> \(normalizedColorSpace)")
            print("   LUT ID: \(lutId)")

            // Update all matching assets that don't have a LUT
            for matchingAsset in matchingAssets {
                // Trigger objectWillChange to ensure views update
                matchingAsset.objectWillChange.send()
                matchingAsset.selectedLUTId = lutId
                print("   ✅ Updated: \(matchingAsset.fileName ?? "unknown") (ID: \(lutId))")
            }

            // Save context
            try context.save()

            // Process pending changes to ensure all updates propagate
            context.processPendingChanges()

            print("✅ Successfully applied learned LUT to \(matchingAssets.count) matching files")
            print("🔄 Changes saved and propagated - views should update")
        } catch {
            print("❌ Failed to apply learned LUT to matching files: \(error)")
        }
    }

    // Normalize string for matching by removing hyphens, dots, and spaces (same as LUTAutoMapper)
    private func normalizeForMatching(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func applyBakingToMatchingFiles() {
        guard let gamma = asset.captureGamma,
              let colorSpace = asset.captureColorPrimaries,
              let lutId = asset.selectedLUTId,
              !gamma.isEmpty,
              !colorSpace.isEmpty,
              !lutId.isEmpty else {
            print("⚠️ Cannot apply baking: missing gamma, colorSpace, or lutId")
            return
        }

        // Normalize the current asset's gamma and colorSpace for matching
        let normalizedGamma = normalizeForMatching(gamma.lowercased())
        let normalizedColorSpace = normalizeForMatching(colorSpace.lowercased())

        // Fetch all assets from Core Data
        let fetchRequest = NSFetchRequest<ManagedVideoAsset>(entityName: "ManagedVideoAsset")

        do {
            guard let context = asset.managedObjectContext else {
                print("❌ No managed object context available")
                return
            }

            let allAssets = try context.fetch(fetchRequest)

            // Filter to matching gamma/colorSpace (excluding the current asset)
            let matchingAssets = allAssets.filter { otherAsset in
                guard otherAsset != asset else { return false }

                guard let otherGamma = otherAsset.captureGamma,
                      let otherColorSpace = otherAsset.captureColorPrimaries else {
                    return false
                }

                // Normalize for comparison
                let otherNormalizedGamma = normalizeForMatching(otherGamma.lowercased())
                let otherNormalizedColorSpace = normalizeForMatching(otherColorSpace.lowercased())

                // Check if gamma and colorSpace match
                return otherNormalizedGamma == normalizedGamma && otherNormalizedColorSpace == normalizedColorSpace
            }

            print("🔥 Applying LUT baking to \(matchingAssets.count) matching files")
            print("   Gamma: \(gamma) -> \(normalizedGamma)")
            print("   Color Space: \(colorSpace) -> \(normalizedColorSpace)")
            print("   LUT ID: \(lutId)")

            // Update all matching assets to use the same LUT and enable baking
            for matchingAsset in matchingAssets {
                matchingAsset.objectWillChange.send()
                matchingAsset.selectedLUTId = lutId
                matchingAsset.bakeInLUT = true
                print("   ✅ Updated: \(matchingAsset.fileName ?? "unknown") - LUT baking enabled")
            }

            // Save context
            try context.save()
            context.processPendingChanges()

            print("✅ Successfully applied LUT baking to \(matchingAssets.count) matching files")
        } catch {
            print("❌ Failed to apply baking to matching files: \(error)")
        }
    }
}
