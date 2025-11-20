//
//  ManagedVideoAsset+Extensions.swift
//  VideoCullingApp
//
//  Created by Gemini on 2025/11/20.
//
// This file is intentionally left empty.
// It is a placeholder to satisfy the Xcode project file reference
// while the codebase is being refactored to remove the unsafe
// bindings it once contained.
//

import CoreData
import SwiftUI

extension ManagedVideoAsset {
    
    // Helper for file URL
    public var fileURL: URL? {
        guard let path = self.filePath else { return nil }
        return URL(fileURLWithPath: path)
    }
}