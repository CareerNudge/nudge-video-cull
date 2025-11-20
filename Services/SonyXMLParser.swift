//
//  SonyXMLParser.swift
//  VideoCullingApp
//

import Foundation

struct SonyXMLMetadata {
    var cameraManufacturer: String = ""
    var cameraModel: String = ""
    var lensModel: String = ""
    var captureGamma: String = ""
    var captureColorPrimaries: String = ""
    var timecode: String = ""
    var captureFps: String = ""
    var hasXMLSidecar: Bool = false
}

class SonyXMLParser: NSObject, XMLParserDelegate {

    private var metadata = SonyXMLMetadata()
    private var currentElement = ""
    private var currentGroupName = ""
    private var currentItemName = ""

    // Parse the XML file at the given URL
    static func parse(xmlURL: URL) -> SonyXMLMetadata? {
        guard FileManager.default.fileExists(atPath: xmlURL.path) else {
            return nil
        }

        guard let parser = XMLParser(contentsOf: xmlURL) else {
            return nil
        }

        let delegate = SonyXMLParser()
        parser.delegate = delegate

        if parser.parse() {
            delegate.metadata.hasXMLSidecar = true
            return delegate.metadata
        } else {
            return nil
        }
    }

    // Look for XML sidecar file for a given video file
    static func findXMLSidecar(for videoURL: URL) -> URL? {
        let videoPath = videoURL.deletingPathExtension().path
        let directory = videoURL.deletingLastPathComponent()
        let baseName = videoURL.deletingPathExtension().lastPathComponent

        // Try multiple common Sony XML naming patterns:
        let patterns = [
            videoPath + ".XML",           // Exact match
            videoPath + ".xml",           // Lowercase
            videoPath + "M01.XML",        // Sony M01 suffix (uppercase)
            videoPath + "M01.xml",        // Sony M01 suffix (lowercase)
            videoPath + "_M01.XML",       // Sony with underscore
            videoPath + "_M01.xml"        // Sony with underscore lowercase
        ]

        for pattern in patterns {
            let xmlURL = URL(fileURLWithPath: pattern)
            if FileManager.default.fileExists(atPath: xmlURL.path) {
                return xmlURL
            }
        }

        // Try searching the directory for any XML file matching the base name
        if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let fileName = fileURL.lastPathComponent
                let fileExtension = fileURL.pathExtension.lowercased()

                // Check if it's an XML file that starts with the base video name
                if fileExtension == "xml" && fileName.hasPrefix(baseName) {
                    return fileURL
                }
            }
        }

        return nil
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "Device":
            if let manufacturer = attributeDict["manufacturer"] {
                metadata.cameraManufacturer = manufacturer
            }
            if let modelName = attributeDict["modelName"] {
                metadata.cameraModel = modelName
            }

        case "Lens":
            if let modelName = attributeDict["modelName"] {
                metadata.lensModel = modelName
            }

        case "VideoFrame":
            if let captureFps = attributeDict["captureFps"] {
                metadata.captureFps = captureFps
            }

        case "LtcChange":
            // Parse timecode from the value attribute
            // The value is in format like "16162602" which represents timecode
            if let value = attributeDict["value"], let tcValue = Int(value) {
                metadata.timecode = formatTimecode(from: tcValue)
            }

        case "Group":
            if let name = attributeDict["name"] {
                currentGroupName = name
            }

        case "Item":
            if currentGroupName == "CameraUnitMetadataSet" {
                if let itemName = attributeDict["name"], let itemValue = attributeDict["value"] {
                    currentItemName = itemName

                    switch itemName {
                    case "CaptureGammaEquation":
                        metadata.captureGamma = itemValue
                    case "CaptureColorPrimaries":
                        metadata.captureColorPrimaries = itemValue
                    default:
                        break
                    }
                }
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Group" {
            currentGroupName = ""
        }
        currentElement = ""
        currentItemName = ""
    }

    // Helper to format timecode value
    private func formatTimecode(from value: Int) -> String {
        // Sony timecode format: HHMMSSFF (8 digits)
        let hours = (value / 1000000) % 100
        let minutes = (value / 10000) % 100
        let seconds = (value / 100) % 100
        let frames = value % 100

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }
}
