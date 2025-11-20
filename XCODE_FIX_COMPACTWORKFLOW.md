# Fix CompactWorkflowView.swift Build Error

## Problem
The file `Views/CompactWorkflowView.swift` exists but Xcode isn't compiling it, causing the error:
```
error: cannot find 'CompactWorkflowView' in scope
```

## Solution

### Option 1: Remove and Re-add the File (Recommended)

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), find `Views/CompactWorkflowView.swift`
3. **Right-click** on `CompactWorkflowView.swift` → **Delete**
4. Choose **"Remove Reference"** (NOT "Move to Trash")
5. **Right-click** on the `Views` folder → **"Add Files to VideoCullingApp"**
6. Navigate to and select `Views/CompactWorkflowView.swift`
7. In the dialog:
   - ✅ Check "VideoCullingApp" under "Add to targets"
   - ❌ Uncheck "Copy items if needed" (file is already in correct location)
   - Select "Create groups" (not "Create folder references")
8. Click **"Add"**
9. Build (Cmd+B)

### Option 2: Check Target Membership

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Select `Views/CompactWorkflowView.swift` in Project Navigator
3. Open the **File Inspector** (right sidebar, first tab)
4. Under **"Target Membership"**:
   - ✅ Ensure **"VideoCullingApp"** is checked
   - ❌ Ensure test targets are NOT checked (if present)
5. Build (Cmd+B)

### Option 3: Verify in Build Phases

1. Open `VideoCullingApp.xcodeproj` in Xcode
2. Select the **VideoCullingApp** project in Navigator
3. Select the **VideoCullingApp** target
4. Go to **"Build Phases"** tab
5. Expand **"Compile Sources"**
6. Check if `CompactWorkflowView.swift` is listed
   - If **NOT listed**: Click the **"+"** button → Add `Views/CompactWorkflowView.swift`
   - If **listed**: Remove it (select and press Delete) then re-add it
7. Build (Cmd+B)

### Option 4: Clean Build Folder

1. In Xcode: **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Close Xcode completely
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/VideoCullingApp-*
   ```
4. Reopen Xcode
5. Build (Cmd+B)

## Expected Result

After fixing, the build should succeed and you'll see the new UI with:
- Visual workflow diagram in the main toolbar
- File counts and space usage under each node
- Big "Process Import/Culling Job" button
- Single "GO!" button on welcome screen

## If Still Not Working

The file might have the wrong permissions. Run:
```bash
chmod 644 Views/CompactWorkflowView.swift
```

Then try Option 1 again (remove reference and re-add).
