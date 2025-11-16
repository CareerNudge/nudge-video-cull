//
//  ContentView.swift
//  VideoCullingApp
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // 1. View model for handling state and logic
    @StateObject private var viewModel: ContentViewModel
    @StateObject private var lutManager = LUTManager.shared
    @State private var showLUTManager = false
    @State private var showPreferences = false

    init() {
        // Initialize the StateObject with the persistence controller
        // This is a way to inject the context into the @StateObject
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: ContentViewModel(context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- TOP TOOLBAR (TWO ROWS) ---
            VStack(spacing: 8) {
                // FIRST ROW: Folder Selection, Naming, and LUT Manager
                HStack {
                    // Input Folder Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input Folder:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Button(action: viewModel.selectInputFolder) {
                                Label("Select", systemImage: "folder.badge.plus")
                            }
                            .disabled(viewModel.isLoading)

                            if let inputURL = viewModel.inputFolderURL {
                                Text(inputURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 120)

                                Button(action: viewModel.closeCurrentFolder) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Close current folder")
                                .disabled(viewModel.isLoading)
                            }
                        }
                    }

                    Divider()
                        .frame(height: 40)
                        .padding(.horizontal, 8)

                    // Output Folder Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output Folder:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Button(action: viewModel.selectOutputFolder) {
                                Label("Select", systemImage: "folder")
                            }
                            .disabled(viewModel.isLoading)

                            if let outputURL = viewModel.outputFolderURL {
                                Text(outputURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 120)
                            }
                        }
                    }

                    Divider()
                        .frame(height: 40)
                        .padding(.horizontal, 8)

                    // Naming Convention Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Re-Naming:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.selectedNamingConvention) {
                            ForEach(NamingConvention.allCases) { convention in
                                Text(convention.rawValue).tag(convention)
                            }
                        }
                        .frame(width: 240)
                        .onChange(of: viewModel.selectedNamingConvention) { newConvention in
                            viewModel.applyNamingConvention(newConvention)
                        }
                    }

                    Divider()
                        .frame(height: 40)
                        .padding(.horizontal, 8)

                    // LUT Manager Button
                    Button(action: {
                        showLUTManager = true
                    }) {
                        Label("LUT Manager", systemImage: "slider.horizontal.3")
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Divider()

                // SECOND ROW: Global LUT, Status, Test Mode, Apply
                HStack {
                    // Global LUT Selector
                    HStack(spacing: 8) {
                        Text("Preview all videos with LUT:")
                            .font(.subheadline)

                        Picker("", selection: $lutManager.globalSelectedLUT) {
                            Text("None").tag(nil as LUT?)
                            ForEach(lutManager.availableLUTs) { lut in
                                Text(lut.name).tag(lut as LUT?)
                            }
                        }
                        .frame(width: 150)
                        .onChange(of: lutManager.globalSelectedLUT) { newLUT in
                            viewModel.applyGlobalLUT(newLUT)
                        }
                    }

                    Spacer()

                    if viewModel.isLoading {
                        VStack(spacing: 8) {
                            if viewModel.totalFilesToProcess > 0 {
                                // Processing mode - show detailed progress
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Processing: \(viewModel.currentProcessingFile)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Text("\(viewModel.currentFileIndex)/\(viewModel.totalFilesToProcess)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 400)

                                    ProgressView(value: viewModel.processingProgress)
                                        .frame(width: 400)
                                        .progressViewStyle(.linear)
                                }
                            } else {
                                // Scanning mode - show spinner
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                    Text(viewModel.loadingStatus)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Test Mode Toggle
                    Toggle(isOn: $viewModel.testMode) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.testMode ? "testtube.2" : "testtube.2")
                                .foregroundColor(viewModel.testMode ? .orange : .secondary)
                            Text("Test Mode")
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.switch)
                    .help("When enabled, exports videos to a 'Culled' subfolder instead of replacing originals")
                    .onChange(of: viewModel.testMode) { _ in
                        viewModel.updateOutputFolder()
                    }

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)

                    Button(action: viewModel.closeCurrentFolder) {
                        Label("Close Current Folder/Project", systemImage: "folder.badge.minus")
                    }
                    .disabled(viewModel.isLoading || viewModel.inputFolderURL == nil)

                    Button(action: viewModel.applyChanges) {
                        Label(viewModel.testMode ? "Test Export" : "Process Video Culling Job", systemImage: "checkmark.circle.fill")
                    }
                    .tint(viewModel.testMode ? .orange : .blue)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.bar)

            Divider()

            // --- MAIN GALLERY ---
            GalleryView()
        }
        .frame(minWidth: 1200, minHeight: 700)
        .onAppear {
            // Apply saved appearance preference on first launch
            PreferencesManager.shared.applyAppearance()
        }
        .sheet(isPresented: $showLUTManager) {
            LUTManagerView(lutManager: lutManager)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}
