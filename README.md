# Nudge Video Cull

A professional macOS video culling application for efficiently reviewing, trimming, and processing video files with LUT support.

## Features

### Core Functionality
- **Video Trimming**: Set precise in/out points with frame-by-frame control
- **LUT Support**: Import, preview, and bake .cube LUTs into videos
- **Batch Processing**: Process multiple videos simultaneously
- **Smart Export**: Automatic preset selection (passthrough for trim-only, re-encode for LUT baking)
- **Test Mode**: Safe testing by exporting to a "Culled" subfolder

### User Interface
- **Frame Preview**: Real-time frame preview when scrubbing trim sliders
- **Audio Waveform**: Visual audio waveform display with trim range highlighting
- **SHIFT Precision**: Hold SHIFT key for frame-by-frame precision control
- **Statistics**: Real-time calculation of total clips, duration, file size, and space savings
- **Sticky Header/Footer**: Column labels and statistics always visible while scrolling
- **Light/Dark Mode**: User-configurable appearance preferences

### Video Processing
- **Native AVFoundation**: 100% App Store compliant, no FFmpeg dependencies
- **LUT Baking**: CoreImage-based color grading with .cube LUT support
- **Lossless Trimming**: Passthrough mode for trim-only operations
- **File Management**: Rename, delete, or organize processed videos

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later (for development)

## Architecture

- **MVVM Pattern**: Clean separation of Views, ViewModels, and Services
- **Core Data**: Efficient video asset management and persistence
- **AVFoundation**: Native video processing and export
- **CoreImage**: LUT color grading with CIColorCube filters
- **SwiftUI**: Modern declarative UI framework

## App Store Compliance

This application is designed for App Store submission with:
- ✅ No GPL/LGPL dependencies
- ✅ Native AVFoundation video processing
- ✅ App Sandboxing ready
- ✅ Security-scoped resource access
- ✅ Privacy descriptions prepared

See `APP_STORE_MIGRATION_STEPS.md` for final submission checklist.

## Documentation

- `COMPLETED_FEATURES.md` - Comprehensive list of implemented features
- `APP_STORE_MIGRATION_STEPS.md` - App Store submission preparation steps
- `appstorereqs.md` - Original App Store requirements specification

## Development

### Key Services
- **ProcessingService**: AVFoundation-based video processing engine
- **LUTParser**: Native .cube LUT file parser
- **LUTManager**: LUT library management
- **ContentViewModel**: Main application state management

### Key Views
- **GalleryView**: Main video gallery with sticky header/footer
- **VideoAssetRowView**: Individual video row layout
- **PlayerView**: Video player with inline playback and preview
- **TrimRangeSlider**: Custom two-handle trim control
- **WaveformView**: Audio waveform visualization

## License

Copyright © 2025. All rights reserved.
