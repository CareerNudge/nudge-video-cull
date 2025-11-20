# Project Overview

This is a professional macOS video culling application named "Nudge Video Cull," designed for efficiently reviewing, trimming, and processing video files. It is written in Swift and SwiftUI, following the Model-View-ViewModel (MVVM) architectural pattern. The application is built for macOS 12.0+ and is intended for distribution on the Mac App Store.

## Core Features

*   **Video Trimming**: Precise in/out points with frame-by-frame control.
*   **LUT Support**: Import, preview, and bake .cube LUTs into videos.
*   **Batch Processing**: Process multiple videos simultaneously.
*   **Smart Export**: Automatic preset selection (passthrough for trim-only, re-encode for LUT baking).
*   **Final Cut Pro X Integration**: Exports an FCPXML file containing the culled video clips.
*   **Sony XML Support**: Parses Sony XAVC metadata.

## Architecture and Technologies

*   **UI**: SwiftUI for a modern, declarative user interface.
*   **Data Persistence**: Core Data for managing video asset information.
*   **Video Processing**: Native `AVFoundation` framework for all video operations, ensuring App Store compliance.
*   **Color Grading**: `CoreImage` for applying LUTs.
*   **Architecture**: MVVM to separate concerns between views, view models, and services.
*   **Dependencies**: The project has no external dependencies like FFmpeg, relying solely on native Apple frameworks.

# Building and Running

## Building the Application

1.  Open `VideoCullingApp.xcodeproj` in Xcode.
2.  Select the "VideoCullingApp" scheme.
3.  Build the project using `Product > Build` (or `Cmd+B`).

## Running the Application

1.  Open `VideoCullingApp.xcodeproj` in Xcode.
2.  Select the "VideoCullingApp" scheme.
3.  Run the application using `Product > Run` (or `Cmd+R`).

## Running Tests

The project contains both unit and UI tests.

*   **Unit Tests**: Run the "VideoCullingAppTests" scheme from Xcode.
*   **UI Tests**: Run the "VideoCullingAppUITests" scheme from Xcode.

There are also several shell scripts for running tests from the command line, such as:

*   `run_tests_20x.sh`: Runs the UI tests 20 times.
*   `run_ui_tests_20x.sh`: Runs the UI tests 20 times.
*   `run_unit_tests_20x.sh`: Runs the unit tests 20 times.

To run the UI tests 20 times, execute the following command in the terminal:

```bash
./run_ui_tests_20x.sh
```

# Development Conventions

*   **Coding Style**: The project follows standard Swift and SwiftUI conventions.
*   **Architecture**: Adheres to the MVVM pattern, with a clear separation of concerns between views, view models, and services.
*   **Testing**: The project has a suite of unit and UI tests. New features should be accompanied by corresponding tests.
*   **App Store Compliance**: The application is designed to be compliant with App Store guidelines, avoiding the use of non-native frameworks for core functionality.

# Key Files

*   `VideoCullingApp.swift`: The main entry point of the application.
*   `ViewModels/ContentViewModel.swift`: The main view model, managing the application's state.
*   `Views/GalleryView.swift`: The main view of the application, displaying the video gallery.
*   `Services/ProcessingService.swift`: The core service for video processing, using `AVFoundation`.
*   `Services/FCPXMLExporter.swift`: Service for exporting Final Cut Pro X compatible XML files.
*   `Services/SonyXMLParser.swift`: Service for parsing Sony XML metadata.
*   `Persistence/Persistence.swift`: Core Data stack setup and configuration.
*   `README.md`: High-level overview of the project.
*   `COMPLETED_FEATURES.md`: Detailed list of implemented features.
*   `APP_STORE_MIGRATION_STEPS.md`: Checklist for App Store submission.
