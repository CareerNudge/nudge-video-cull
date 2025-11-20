# Manual Xcode Configuration Steps

## Files to Add to Xcode Project

The following files have been created but need to be manually added to the Xcode project:

### REQUIRED: Sony XML Metadata Support
These files MUST be added for the app to build successfully:

#### 1. SonyXMLParser.swift ⚠️ REQUIRED
- **Location:** `Services/SonyXMLParser.swift`
- **Steps to add:**
  1. Open Xcode
  2. Right-click on the "Services" folder in the Project Navigator
  3. Select "Add Files to VideoCullingApp..."
  4. Navigate to and select `Services/SonyXMLParser.swift`
  5. Ensure "Copy items if needed" is checked
  6. Ensure "VideoCullingApp" target is selected
  7. Click "Add"

#### 2. LUTAutoMapper.swift ⚠️ REQUIRED
- **Location:** `Services/LUTAutoMapper.swift`
- **Steps to add:**
  1. Open Xcode
  2. Right-click on the "Services" folder in the Project Navigator
  3. Select "Add Files to VideoCullingApp..."
  4. Navigate to and select `Services/LUTAutoMapper.swift`
  5. Ensure "Copy items if needed" is checked
  6. Ensure "VideoCullingApp" target is selected
  7. Click "Add"

#### 3. EnrichedMetadataView.swift ⚠️ REQUIRED
- **Location:** `Views/RowSubviews/EnrichedMetadataView.swift` OR `Views/EnrichedMetadataView.swift`
- **Steps to add:**
  1. Open Xcode
  2. Right-click on the "Views/RowSubviews" folder in the Project Navigator
  3. Select "Add Files to VideoCullingApp..."
  4. Navigate to and select `Views/RowSubviews/EnrichedMetadataView.swift`
  5. Ensure "Copy items if needed" is checked
  6. Ensure "VideoCullingApp" target is selected
  7. Click "Add"

#### 4. TipsManager.swift ⚠️ REQUIRED
- **Location:** `Services/TipsManager.swift`
- **Steps to add:**
  1. Open Xcode
  2. Right-click on the "Services" folder in the Project Navigator
  3. Select "Add Files to VideoCullingApp..."
  4. Navigate to and select `Services/TipsManager.swift`
  5. Ensure "Copy items if needed" is checked
  6. Ensure "VideoCullingApp" target is selected
  7. Click "Add"

#### 5. tips.json ⚠️ REQUIRED
- **Location:** `Resources/tips.json`
- **Steps to add:**
  1. Open Xcode
  2. Right-click on the project root (VideoCullingApp) in the Project Navigator
  3. Select "Add Files to VideoCullingApp..."
  4. Navigate to and select `Resources/tips.json`
  5. Ensure "Copy items if needed" is checked
  6. Ensure "VideoCullingApp" target is selected
  7. Click "Add"

### Previously Created (May Already Be Added)

#### 3. FCPXMLExporter.swift
- **Location:** `Services/FCPXMLExporter.swift`
- Follow same steps as #1, adding to the "Services" folder

#### 4. WelcomeView.swift
- **Location:** `Views/WelcomeView.swift`
- Follow same steps as #2, adding to the "Views" folder

#### 5. ProcessingProgressView.swift
- **Location:** `Views/ProcessingProgressView.swift`
- Follow same steps as #2, adding to the "Views" folder

### REQUIRED: DefaultLuts Folder
The DefaultLuts folder must be added as a folder reference (not a group) to be included in the app bundle:

#### Add DefaultLuts Folder ⚠️ REQUIRED
- **Location:** `DefaultLuts` (in project root)
- **Steps to add:**
  1. Open Xcode
  2. Right-click on the project root (VideoCullingApp) in the Project Navigator
  3. Select "Add Files to VideoCullingApp..."
  4. Navigate to and select the `DefaultLuts` folder
  5. **IMPORTANT:** Choose **"Create folder references"** (blue folder icon, NOT yellow groups)
  6. Ensure "VideoCullingApp" target is checked
  7. Click "Add"

This ensures the folder structure is preserved in the app bundle and all LUT files are automatically available.

## After Adding Files

Once all files are added, rebuild the project:
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Product → Build (Cmd+B)
