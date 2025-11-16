//
//  WelcomeView.swift
//  VideoCullingApp
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Welcome card
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.waveform.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Welcome to Nudge Video Cull")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Professional video culling and processing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)

                // Workflow steps (horizontal)
                HStack(spacing: 20) {
                    // Step 1
                    WorkflowStep(
                        number: 1,
                        icon: "folder.badge.plus",
                        iconColor: .blue,
                        title: "Source Media",
                        description: "Select your input folder containing videos from your camera, SD card, or any storage device"
                    )

                    // Arrow right
                    Image(systemName: "arrow.right")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(width: 40)

                    // Step 2
                    WorkflowStep(
                        number: 2,
                        icon: "slider.horizontal.3",
                        iconColor: .orange,
                        title: "Selective Trimming & LUT Pre-Bake",
                        description: "Trim unwanted portions, apply color grading LUTs, rename files, and mark clips for deletion"
                    )

                    // Arrow right
                    Image(systemName: "arrow.right")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(width: 40)

                    // Step 3
                    WorkflowStep(
                        number: 3,
                        icon: "folder.badge.checkmark",
                        iconColor: .green,
                        title: "Destination Folder",
                        description: "Process all videos to your chosen output folder with trim, LUT, and rename operations applied"
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

                // Bottom section
                VStack(spacing: 16) {
                    Divider()

                    // Don't show again checkbox
                    Toggle(isOn: $hasSeenWelcome) {
                        Text("Don't show this again")
                            .font(.subheadline)
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal, 40)

                    // Get Started button
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
                }
            }
            .frame(width: 900)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
        }
    }
}

// MARK: - Workflow Step Component
struct WorkflowStep: View {
    let number: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(iconColor)
            }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
                .frame(width: 70, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconColor.opacity(0.1))
                )

            // Text content
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview
#Preview {
    WelcomeView(isPresented: .constant(true))
}
