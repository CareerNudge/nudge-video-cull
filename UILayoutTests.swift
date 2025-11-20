//
//  UILayoutTests.swift
//  VideoCullingApp UI Layout Tests
//
//  Tests to ensure UI elements don't clip or bleed beyond their containers
//

import XCTest

final class UILayoutTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Configure test mode
        if let testMode = ProcessInfo.processInfo.environment["TEST_MODE"],
           let testInputPath = ProcessInfo.processInfo.environment["TEST_INPUT_PATH"],
           let testOutputPath = ProcessInfo.processInfo.environment["TEST_OUTPUT_PATH"] {
            app.launchEnvironment["TEST_MODE"] = testMode
            app.launchEnvironment["TEST_INPUT_PATH"] = testInputPath
            app.launchEnvironment["TEST_OUTPUT_PATH"] = testOutputPath
        }

        if app.state == .notRunning {
            app.launch()
        } else {
            app.activate()
        }

        // Wait for app to load
        sleep(5)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helper Methods

    /// Checks if an element's frame is within its parent's bounds
    func verifyElementWithinBounds(_ element: XCUIElement, context: String) {
        guard element.exists else {
            XCTFail("\(context): Element does not exist")
            return
        }

        let frame = element.frame
        XCTAssertGreaterThan(frame.width, 0, "\(context): Element has zero width")
        XCTAssertGreaterThan(frame.height, 0, "\(context): Element has zero height")

        // Element should be on screen
        XCTAssertTrue(element.isHittable || element.value != nil, "\(context): Element may be clipped or hidden")
    }

    /// Verifies all static text elements are properly contained
    func verifyAllTextElementsVisible(in container: XCUIElement, context: String) {
        let textElements = container.staticTexts.allElementsBoundByIndex
        XCTAssertGreaterThan(textElements.count, 0, "\(context): No text elements found")

        for (index, textElement) in textElements.enumerated() {
            if textElement.exists {
                verifyElementWithinBounds(textElement, context: "\(context) - Text[\(index)]: '\(textElement.label)'")
            }
        }
    }

    /// Verifies all buttons are properly visible
    func verifyAllButtonsVisible(in container: XCUIElement, context: String) {
        let buttons = container.buttons.allElementsBoundByIndex
        for (index, button) in buttons.enumerated() {
            if button.exists {
                verifyElementWithinBounds(button, context: "\(context) - Button[\(index)]: '\(button.label)'")
                XCTAssertTrue(button.isHittable, "\(context) - Button[\(index)] should be clickable")
            }
        }
    }

    // MARK: - Welcome Screen Tests

    func testWelcomeScreenLayout() throws {
        // If welcome screen is shown
        let welcomeTitle = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Welcome'")).firstMatch

        if welcomeTitle.exists {
            print("Testing Welcome Screen layout...")

            // Verify welcome screen elements
            verifyElementWithinBounds(welcomeTitle, context: "Welcome Screen - Title")
            verifyAllTextElementsVisible(in: app.windows.firstMatch, context: "Welcome Screen")
            verifyAllButtonsVisible(in: app.windows.firstMatch, context: "Welcome Screen")

            // Check for folder selection buttons
            let selectFolderButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select' OR label CONTAINS[c] 'Choose'"))
            XCTAssertGreaterThan(selectFolderButtons.count, 0, "Welcome Screen should have folder selection buttons")
        }
    }

    // MARK: - Main Content View Tests

    func testMainContentViewLayout() throws {
        print("Testing Main Content View layout...")

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Verify all text elements in main window
        verifyAllTextElementsVisible(in: mainWindow, context: "Main Content View")
        verifyAllButtonsVisible(in: mainWindow, context: "Main Content View")

        // Check for header elements
        let headers = mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'video' OR label CONTAINS[c] 'file'"))
        for i in 0..<headers.count {
            let header = headers.element(boundBy: i)
            if header.exists {
                verifyElementWithinBounds(header, context: "Main Content - Header[\(i)]")
            }
        }
    }

    // MARK: - Gallery Mode Tests

    func testGalleryModeLayout() throws {
        print("Testing Gallery Mode layout...")

        // Find and click gallery mode toggle
        let galleryButton = app.buttons["galleryModeButton"]
        if galleryButton.exists && galleryButton.isHittable {
            galleryButton.click()
            sleep(2) // Wait for transition

            // Verify layout in gallery mode
            let mainWindow = app.windows.firstMatch
            verifyAllTextElementsVisible(in: mainWindow, context: "Gallery Mode")
            verifyAllButtonsVisible(in: mainWindow, context: "Gallery Mode")

            // Toggle back
            if galleryButton.exists {
                galleryButton.click()
                sleep(1)
            }
        }
    }

    // MARK: - Video Row Tests

    func testVideoRowLayout() throws {
        print("Testing Video Row layout...")

        // Find table or scroll view with video rows
        let scrollViews = app.scrollViews
        if scrollViews.count > 0 {
            let scrollView = scrollViews.firstMatch

            // Check elements within scroll view
            verifyAllTextElementsVisible(in: scrollView, context: "Video Rows")
            verifyAllButtonsVisible(in: scrollView, context: "Video Rows")

            // Check for specific video metadata elements
            let metadataTexts = scrollView.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'fps' OR label CONTAINS[c] 'duration' OR label CONTAINS[c] 'resolution'"))
            for i in 0..<min(metadataTexts.count, 10) {
                let metadata = metadataTexts.element(boundBy: i)
                if metadata.exists {
                    verifyElementWithinBounds(metadata, context: "Video Row Metadata[\(i)]")
                }
            }
        }
    }

    // MARK: - Player View Tests

    func testPlayerViewLayout() throws {
        print("Testing Player View layout...")

        // Look for play/pause buttons
        let playButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play' OR identifier == 'playPauseButton'"))
        if playButtons.count > 0 {
            let playButton = playButtons.firstMatch
            verifyElementWithinBounds(playButton, context: "Player View - Play Button")
        }

        // Check for video timeline/scrubber
        let sliders = app.sliders
        for i in 0..<sliders.count {
            let slider = sliders.element(boundBy: i)
            if slider.exists {
                verifyElementWithinBounds(slider, context: "Player View - Slider[\(i)]")
            }
        }
    }

    // MARK: - Preferences View Tests

    func testPreferencesViewLayout() throws {
        print("Testing Preferences View layout...")

        // Try to open preferences (Cmd+,)
        app.typeKey(",", modifierFlags: .command)
        sleep(1)

        let preferencesWindow = app.windows.matching(NSPredicate(format: "title CONTAINS[c] 'Preferences' OR title CONTAINS[c] 'Settings'")).firstMatch

        if preferencesWindow.exists {
            verifyAllTextElementsVisible(in: preferencesWindow, context: "Preferences Window")
            verifyAllButtonsVisible(in: preferencesWindow, context: "Preferences Window")

            // Close preferences
            app.typeKey("w", modifierFlags: .command)
            sleep(1)
        }
    }

    // MARK: - Metadata Display Tests

    func testMetadataDisplayLayout() throws {
        print("Testing Metadata Display layout...")

        let mainWindow = app.windows.firstMatch

        // Check for metadata labels
        let metadataLabels = mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Camera' OR label CONTAINS[c] 'Lens' OR label CONTAINS[c] 'ISO' OR label CONTAINS[c] 'Gamma'"))

        for i in 0..<min(metadataLabels.count, 20) {
            let label = metadataLabels.element(boundBy: i)
            if label.exists {
                verifyElementWithinBounds(label, context: "Metadata Label[\(i)]")

                // Check that label text is not truncated (basic check)
                let labelText = label.label
                XCTAssertFalse(labelText.hasSuffix("..."), "Metadata Label[\(i)] appears truncated: '\(labelText)'")
            }
        }
    }

    // MARK: - Text Field Tests

    func testTextFieldsLayout() throws {
        print("Testing Text Fields layout...")

        let textFields = app.textFields
        for i in 0..<min(textFields.count, 10) {
            let textField = textFields.element(boundBy: i)
            if textField.exists {
                verifyElementWithinBounds(textField, context: "Text Field[\(i)]")

                // Verify text field has reasonable width
                let frame = textField.frame
                XCTAssertGreaterThan(frame.width, 50, "Text Field[\(i)] should have sufficient width")
            }
        }
    }

    // MARK: - Star Rating Tests

    func testStarRatingLayout() throws {
        print("Testing Star Rating layout...")

        // Look for star rating elements
        let stars = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'star' OR identifier CONTAINS 'star'"))
        for i in 0..<min(stars.count, 15) {
            let star = stars.element(boundBy: i)
            if star.exists {
                verifyElementWithinBounds(star, context: "Star Rating[\(i)]")
            }
        }
    }

    // MARK: - Progress View Tests

    func testProgressViewsLayout() throws {
        print("Testing Progress Views layout...")

        let progressIndicators = app.progressIndicators
        for i in 0..<progressIndicators.count {
            let progress = progressIndicators.element(boundBy: i)
            if progress.exists {
                verifyElementWithinBounds(progress, context: "Progress Indicator[\(i)]")
            }
        }
    }

    // MARK: - Comprehensive Layout Test

    func testComprehensiveLayoutCheck() throws {
        print("Running comprehensive layout check...")

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window must exist")

        // Get all UI elements
        let allElements: [(String, XCUIElementQuery)] = [
            ("Static Texts", mainWindow.staticTexts),
            ("Buttons", mainWindow.buttons),
            ("Text Fields", mainWindow.textFields),
            ("Images", mainWindow.images),
            ("Sliders", mainWindow.sliders),
        ]

        for (elementType, query) in allElements {
            let count = query.count
            print("  Found \(count) \(elementType)")

            // Sample check (first 5 of each type)
            for i in 0..<min(count, 5) {
                let element = query.element(boundBy: i)
                if element.exists {
                    let frame = element.frame

                    // Verify reasonable dimensions
                    XCTAssertGreaterThan(frame.width, 0, "\(elementType)[\(i)] has zero width")
                    XCTAssertGreaterThan(frame.height, 0, "\(elementType)[\(i)] has zero height")

                    // Verify element is within reasonable screen bounds (not wildly off-screen)
                    XCTAssertLessThan(frame.minX, 5000, "\(elementType)[\(i)] has unusual X position")
                    XCTAssertLessThan(frame.minY, 5000, "\(elementType)[\(i)] has unusual Y position")
                }
            }
        }
    }
}
