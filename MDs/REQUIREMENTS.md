======================================================================
PROJECT: "Video Culling Tool" for macOS
======================================================================

1. PROJECT GOAL
Create a native macOS application that allows a user to select a folder of video clips and displays them in a single, vertically scrolling window. The app is intended to be used on a widescreen display. Each video will be represented by a horizontal row containing (from left to right): 1) A video player/trimmer, 2) Editable management fields, and 3) Static file metadata. The user must be able to play, rate, flag, rename, and set lossless trim points for each video. A final "Apply Changes" action processes all queued operations.

2. CORE FEATURES (FUNCTIONAL REQUIREMENTS)

2.1. Folder Selection:
- The app must provide a button to trigger a native macOS `NSOpenPanel`.
- The user must be able to select a single directory.
- Upon selection, the app must recursively scan the directory for valid video files (e.g., .mp4, .mov, .m4v).

2.2. Video Gallery Display:
- All found video files must be displayed in a single, vertically scrolling list.
- The list MUST use "lazy loading" (like `LazyVStack` in SwiftUI) to ensure performance.

2.3. Per-Video Item Display (Horizontal Row):
- Each item in the list represents one video file and must be laid out in a horizontal `HStack` with three main columns.

- **Column 1: Video Player & Trimmer:**
  - A video thumbnail (which acts as a "play" button).
  - Clicking plays the video inline.
  - A visual range slider representing the video's timeline for setting trim in/out points.

- **Column 2: Editable Fields:**
  - **Editable File Name:** A `TextField` for the file name (without extension).
  - **Flag for Deletion:** A `Toggle` (switch) labeled "Flag for Deletion."
  - **Rating:** A 1-5 star rating selector.
  - **Keywords:** A `TextField` for adding comma-separated keywords (or tags).

- **Column 3: Metadata:**
  - **Size:** Original file size (in MB/GB).
  - **Duration:** Original video duration (HH:MM:SS).
  - **Frame Rate:** (e.g., 29.97 FPS).
  - **Bitrate:** (e.g., 50 Mbps).
  - **Creation Date:** File creation timestamp.
  - **Last Edit Date:** File modification timestamp.

2.4. Dynamic Trim Feedback (NEW):
- When the user adjusts the trim sliders (setting in/out points), the "Duration" and "Size" text fields in the Metadata column must:
  1. Calculate the *estimated* new duration based on the trim range.
  2. Calculate the *estimated* new file size (using `(Original Size / Original Duration) * New Duration`).
  3. Display these new estimated values in **RED TEXT** to indicate they are not yet saved and are an estimate.
- If the trim sliders are reset to the full clip, the text must revert to its original color and value.

2.5. Persistence:
- All user-generated data (ratings, flags, trim points, new names, keywords) MUST be saved to a persistent store (e.g., a database) *as soon as the user makes the change*. This is critical for non-destructive editing and ensuring data survives an app quit.

2.6. Batch Processing ("Apply Changes"):
- A single, global "Apply Changes" button.
- When clicked, the app processes all files in the list.
- **Processing Order:**
  1. DELETION: All files flagged for deletion (Toggle=On) are moved to the system Trash.
  2. TRIMMING: For files with trim points set, the app executes a lossless trim, replacing the original file.
  3. RENAMING: All files with a new name are renamed.
- A progress bar or status indicator must be shown during this operation.

3. NON-FUNCTIONAL REQUIREMENTS

3.1. Platform: macOS (target macOS 13.0+).
3.2. Performance: UI must remain responsive. All file I/O must be on background threads.
3.3. Persistence: Core Data or SQLite (via GRDB.swift) is required. The `filePath` must be the unique key.
3.4. Lossless Trimming: This is non-negotiable. It MUST use a stream copy method, not re-encoding.
3.5. Error Handling: Must gracefully handle file-not-found errors (if deleted outside the app) and processing failures.

4. RECOMMENDED ARCHITECTURE & TECH STACK

4.1. Language/Framework: Swift with SwiftUI.
4.2. Architecture: Model-View-ViewModel (MVVM).

4.3. Core Model (Data Struct):
  - `VideoAsset`:
    - `id`: UUID
    - `filePath`: URL (Unique Key)
    - `fileName`: String
    - `fileSize`: Int64 (Original size in bytes)
    - `duration`: Double (Original duration in seconds)
    - `frameRate`: Double
    - `bitrate`: Int (in bps)
    - `creationDate`: Date
    - `lastEditDate`: Date
    - `userRating`: Int (default 0)
    - `isFlaggedForDeletion`: Bool (default false)
    - `keywords`: String (default "")
    - `newFileName`: String (default "")
    - `trimStartTime`: Double (default 0)
    - `trimEndTime`: Double (default 0, 0 means "end of clip")

4.4. Backend Services:
  - `FileScannerService`: Scans folders using `FileManager`.
  - `MetadataExtractorService`: Uses `AVFoundation` (`AVAsset`) to *asynchronously* get all metadata (duration, FPS, bitrate, tracks, creation date) and `AVAssetImageGenerator` for thumbnails.
  - `PersistenceService`: Manages all database reads/writes (Core Data or GRDB).
  - `ProcessingService`: Runs the "Apply Changes" batch.
    - Uses `FileManager.trashItem` for deletion.
    - Uses `FileManager.moveItem` for renaming.
    - Uses `Process` API to call a bundled `ffmpeg` binary for trimming.

4.5. FFmpeg (Trimming):
  - The app MUST bundle a static `ffmpeg` binary.
  - **FFmpeg Command:**
    `ffmpeg -i "INPUT_FILE_PATH" -ss [START_TIME_IN_SEC] -to [END_TIME_IN_SEC] -c copy "TEMP_OUTPUT_FILE_PATH"`
  - The `-c copy` flag is mandatory for lossless trimming.
  - The app must then replace the original file with the temp file.

4.6. Views (SwiftUI):
  - `ContentView`: Holds the folder picker and the `GalleryView`.
  - `GalleryView`: The `ScrollView` + `LazyVStack` that holds the rows.
  - `VideoAssetRowView`: The view for a single item.
    - This view will be the most complex. It will hold its own `VideoAsset` object (or a `ViewModel` for it).
    - It will contain the `HStack` with the three columns.
    - It must contain the logic for the dynamic/red text:
      - Use `@State` variables for the *current* slider `trimStart` and `trimEnd`.
      - When these `@State` vars change, a computed property `isTrimmed` becomes true.
      - The `Text` views for Duration and Size will be:
        - `Text(calculateEstimatedDuration())`
        - `.foregroundColor(isTrimmed ? .red : .primary)`
      - The `calculateEstimatedDuration()` and `calculateEstimatedSize()` functions will live inside this view or its ViewModel.

5. STEP-BY-STEP BUILD APPROACH (for Agent)

1.  **Project Setup:** New macOS SwiftUI app.
2.  **Model & Persistence:** Define the `VideoAsset` struct. Set up Core Data and the `ManagedVideoAsset` entity. Create `PersistenceService`.
3.  **Core Services:** Build `FileScannerService` and `MetadataExtractorService`.
4.  **UI (Shell):** Create `ContentView` with folder picker. On select, run the scanner and metadata services, populating the database.
5.  **UI (Gallery):** Create `GalleryView`. Use a `FetchRequest` (for Core Data) to get the list of assets and display them in a `LazyVStack`.
6.  **UI (Row - Layout):** Build `VideoAssetRowView`. Create the 3-column `HStack` layout.
7.  **Row (Column 1):** Add `VideoPlayer` and a custom `TrimSliderView`. Bind slider values to `@State` vars.
8.  **Row (Column 2):** Add `TextField` (rename), `Toggle` (delete), `StarRatingView` (custom), and `TextField` (keywords). Bind these *directly* to the Core Data object.
9.  **Row (Column 3):** Display the static metadata.
10. **Row (Dynamic Text):** Implement the logic in `VideoAssetRowView`. When the trim `@State` vars change, update the persistent `trimStartTime` / `trimEndTime` on the Core Data object. The `Text` views for Size and Duration must check `trimStartTime` and `trimEndTime` and apply the red color and estimated calculation if they are different from the defaults.
11. **FFmpeg:** Add the `ffmpeg` binary to the project.
12. **Processing:** Build the `ProcessingService` and the "Apply Changes" button logic.
13. **Refine:** Add progress indicators and error handling.

======================================================================
CORE DATA MODEL SETUP (.xcdatamodeld)
======================================================================

This file must be created visually in Xcode.

1.  Click on the `VideoCullingApp.xcdatamodeld` file in the Xcode navigator.
2.  Click **Add Entity** and rename the new entity to `ManagedVideoAsset`.
3.  In the Data Model Inspector on the right, set **Codegen** to **Class Definition**.
4.  Add the following attributes to the `ManagedVideoAsset` entity:

| Attribute             | Type        | Notes                                |
| :-------------------- | :---------- | :----------------------------------- |
| `id`                  | UUID        |                                      |
| `filePath`            | String      | **Constraint:** Add `filePath`         |
| `fileName`            | String      |                                      |
| `fileSize`            | Integer 64  |                                      |
| `duration`            | Double      |                                      |
| `frameRate`           | Double      |                                      |
| `bitrate`             | Integer 64  |                                      |
| `creationDate`        | Date        |                                      |
| `lastEditDate`        | Date        |                                      |
| `userRating`          | Integer 16  | Default: 0                           |
| `isFlaggedForDeletion`| Boolean     | Default: `No`                        |
| `keywords`            | String      | Default: `""`                        |
| `newFileName`         | String      | Default: `""`                        |
| `trimStartTime`       | Double      | Default: 0                           |
| `trimEndTime`         | Double      | Default: 0                           |
