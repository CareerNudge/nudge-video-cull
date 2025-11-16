
  1. Remove FFmpeg from Build Phases (5 minutes)
    - Open project → Target → Build Phases → Copy Bundle Resources
    - Remove ffmpeg entry
  2. Add LUTParser.swift to Project (2 minutes)
    - Right-click Services folder → Add Files
    - Select LUTParser.swift
  3. Enable App Sandboxing (5 minutes)
    - Target → Signing & Capabilities → Add "App Sandbox"
    - Enable User Selected File (Read/Write)
  4. Add Privacy Descriptions to Info.plist (5 minutes)
    - Add Photo Library, Desktop, Documents usage descriptions
  5. StoreKit 2 Integration (30-60 minutes)
    - Set up subscription in App Store Connect
    - Implement SubscriptionManager (code provided in migration doc)