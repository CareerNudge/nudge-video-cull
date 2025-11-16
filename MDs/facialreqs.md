======================================================================
PROJECT: "Video Culling Tool" - Feature: On-Device Facial Recognition
======================================================================

1. PROJECT GOAL
Extend the existing application to include on-device facial recognition. The app must be able to scan all videos in the working folder, identify and cluster unique faces, allow the user to name these faces, and then use this data to filter the main video gallery. All processing MUST be on-device.

2. PREREQUISITES (External Dependencies)

2.1. Core ML Model:
- The app MUST bundle a pre-trained facial recognition `.mlmodel`.
- A "FaceNet" or "VGGFace" model is recommended. These models take a cropped face image as input and output a vector (e.g., a 128- or 512-dimension array) known as a "faceprint" or "embedding".
- The coding agent must add this `.mlmodel` file to the Xcode project.

3. REQUIRED CHANGES (Data Model)

3.1. Modify Core Data Model (`VideoCullingApp.xcdatamodeld`):
- The agent MUST modify the Core Data model to add three new entities:

- **Entity 1: `Person`**
  - This entity represents a named individual.
  - **Attributes:**
    - `id`: UUID (Unique ID)
    - `name`: String (The user-assigned name, e.g., "Dad")
    - `isUnknown`: Boolean (Default: `true`. Becomes `false` when a name is set)
  - **Relationships:**
    - `faceInstances`: One-to-Many relationship with `FaceInstance`.
    - `representativeFace`: One-to-One relationship with `FaceInstance` (to store the "best" thumbnail for this person).

- **Entity 2: `FaceInstance`**
  - This represents a *single detection* of a face in a specific video.
  - **Attributes:**
    - `id`: UUID
    - `timestamp`: Double (The time in seconds where the face was found in the video)
    - `boundingBox`: String (The coordinates of the face, e.g., "x,y,width,height")
    - `faceprint`: Data (The 128- or 512-dimension vector from the Core ML model)
    - `thumbnail`: Data (A small `jpeg` or `png` of the cropped face)
  - **Relationships:**
    - `videoAsset`: Many-to-One relationship with `ManagedVideoAsset`.
    - `person`: Many-to-One relationship with `Person`.

- **Entity 3: Modify `ManagedVideoAsset`**
  - **New Attribute:**
    - `isFaceScanned`: Boolean (Default: `false`. Set to `true` after scanning is complete)
  - **New Relationship:**
    - `faceInstances`: One-to-Many relationship with `FaceInstance`.

4. REQUIRED CHANGES (Backend Services)

4.1. Create `FaceRecognitionService.swift`:
- This new service will manage all scanning and clustering. It must run on a background thread.
- **Method 1: `scanAssetsForFaces()`**
  - 1. Fetch all `ManagedVideoAsset`s where `isFaceScanned == false`.
  - 2. For each asset, use `AVAssetImageGenerator` to extract frames (e.g., 1 frame per second).
  - 3. For each frame, use the **Vision framework** (`VNDetectFaceRectanglesRequest`) to find all face bounding boxes.
  - 4. For each face found:
    - a. Crop the face from the frame using the bounding box.
    - b. Feed the cropped image to the Core ML model (e.g., FaceNet) to get the "faceprint" (vector).
    - c. Create a new `FaceInstance` object in Core Data.
    - d. Store the `timestamp`, `boundingBox`, `faceprint`, and the cropped `thumbnail` image.
    - e.Link this `FaceInstance` to its parent `ManagedVideoAsset`.
  - 5. After the video is finished, set `videoAsset.isFaceScanned = true`.
- **Method 2: `clusterFaces()`**
  - 1. This method is called after scanning.
  - 2. Fetch all `FaceInstance`s that do *not* have a `person` relationship set.
  - 3. Compare the `faceprint` of the first instance to all others (using Euclidean distance or cosine similarity).
  - 4. If the distance is below a set threshold, group them.
  - 5. For each new group, create a new `Person` object (with `isUnknown = true`) and link all `FaceInstance`s in that group to it.
  - 6. Select the "best" `FaceInstance` (e.g., largest, clearest) and set it as the `representativeFace` for the new `Person`.

4.2. Modify `ContentViewModel.swift`:
- Add a new "Scan for Faces" button/action that calls `FaceRecognitionService.scanAssetsForFaces()` and then `FaceRecognitionService.clusterFaces()`.
- Provide progress updates to the UI (e.g., "Scanning video 5 of 100...").

5. REQUIRED CHANGES (User Interface)

5.1. Create `PeopleView.swift` (The "List of Faces"):
- This view is presented as a modal sheet when the user clicks a new "People" button in the `ContentView` toolbar.
- It must perform a `FetchRequest` for all `Person` entities, sorted by `isUnknown` (so "Unknown" faces are first).
- It must display a `LazyVGrid` of all `Person` objects.
- Each item in the grid must show:
  - The `representativeFace.thumbnail` image.
  - A `TextField` bound to `person.name`. The prompt should say "Add Name".
  - When the user types a name and hits Enter, `person.isUnknown` must be set to `false`.

5.2. Create `PersonDetailView.swift` (Confirming Matches):
- When a user clicks a `Person` in the `PeopleView`, they navigate here.
- This view shows all `FaceInstance.thumbnail` images associated with this `Person`.
- **Crucially:** It must also show a "Suggested Matches" section.
  - This section finds other `FaceInstance`s (belonging to "Unknown" `Person`s) whose `faceprint`s are very close, but not identical, to this `Person`'s average faceprint.
  - For each suggestion, show the face thumbnail and two buttons: "Confirm" (merges the face into this `Person`) and "Deny" (marks it as not a match).

5.3. Modify `ContentView.swift` (Filtering):
- Add a new "Filter" `Menu` or `Popover` to the toolbar.
- This filter UI must fetch all `Person` objects where `isUnknown == false`.
- For each named `Person`, it must provide "Include" and "Exclude" options.
- The user's filter selections (e.g., "Include: Dad", "Exclude: Mom") must be stored in the `ContentViewModel`.

5.4. Modify `GalleryView.swift` (Applying Filters):
- The `GalleryView`'s `@FetchRequest` must be modified to be dynamic.
- It must accept the filter criteria from the `ContentViewModel`.
- The `NSPredicate` of the `FetchRequest` must be updated to filter the `ManagedVideoAsset` list.
- **Example Predicate (Include "Dad"):**
  - `NSPredicate(format: "ANY faceInstances.person.name == %@", "Dad")`
- **Example Predicate (Exclude "Mom"):**
  - `NSPredicate(format: "NONE faceInstances.person.name == %@", "Mom")`
- **Example Predicate (Include "Dad" AND Exclude "Mom"):**
  - `NSCompoundPredicate(andPredicateWithSubpredicates: [predicateDad, predicateMom])`

======================================================================
END OF FILE
======================================================================