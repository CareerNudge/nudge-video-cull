//
//  ManagedVideoAsset+Extensions.swift
//  VideoCullingApp
//

import CoreData
import SwiftUI

/*
  This extension provides clean, non-optional Bindings for SwiftUI.
  Core Data generates properties like `newFileName` as `String?`.
  SwiftUI's TextField works best with a non-optional `Binding<String>`.
 
  This extension creates a "bridge", ensuring that if the Core Data
  value is nil, SwiftUI gets an empty string (""), and any changes
  are saved back to Core Data.
*/
extension ManagedVideoAsset {
    
    // Binding for the new file name
    public var newFileName_bind: Binding<String> {
        Binding<String>(
            get: { self.newFileName ?? "" },
            set: { self.newFileName = $0 }
        )
    }
    
    // Binding for the keywords
    public var keywords_bind: Binding<String> {
        Binding<String>(
            get: { self.keywords ?? "" },
            set: { self.keywords = $0 }
        )
    }
    
    // Helper for file URL
    public var fileURL: URL? {
        guard let path = self.filePath else { return nil }
        return URL(fileURLWithPath: path)
    }
}
