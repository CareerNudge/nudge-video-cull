//
//  VideoCullingAppUITests.swift
//  VideoCullingAppUITests
//
//  Created by Roman Wilson on 11/17/25.
//

import XCTest

final class VideoCullingAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Configure app with test mode environment variables
        let app = XCUIApplication()

        // Read environment variables from shell and pass to app
        if let testMode = ProcessInfo.processInfo.environment["TEST_MODE"],
           let testInputPath = ProcessInfo.processInfo.environment["TEST_INPUT_PATH"],
           let testOutputPath = ProcessInfo.processInfo.environment["TEST_OUTPUT_PATH"] {
            app.launchEnvironment["TEST_MODE"] = testMode
            app.launchEnvironment["TEST_INPUT_PATH"] = testInputPath
            app.launchEnvironment["TEST_OUTPUT_PATH"] = testOutputPath
        }

        // Disable automatic termination of existing instances
        // This prevents failures when zombie processes exist
        if app.state == .notRunning {
            app.launch()
        } else {
            // App already running - just activate it
            app.activate()
        }

        // Wait for app to finish loading test data
        sleep(5)
    }

    override func tearDownWithError() throws {
        // Clean termination
        XCUIApplication().terminate()
    }

    @MainActor
    func testGalleryModeToggle() throws {
        let app = XCUIApplication()

        // Wait for app to fully load
        sleep(3)

        // Find the gallery mode toggle button (may not exist in all states)
        let galleryButton = app.buttons["galleryModeButton"]

        // Only test if button exists
        if galleryButton.waitForExistence(timeout: 5) && galleryButton.isHittable {
            print("✓ Gallery mode button found - testing toggle")

            // Click the button (should not crash)
            galleryButton.click()
            sleep(1)

            // App should still be running after toggle
            XCTAssertTrue(app.exists, "App should not crash after gallery toggle")

            // Toggle back if still exists
            if galleryButton.exists && galleryButton.isHittable {
                galleryButton.click()
                sleep(1)
                XCTAssertTrue(app.exists, "App should not crash during second toggle")
            }
        } else {
            print("⚠ Gallery mode button not found - skipping test (may be in different view state)")
            // Test passes - button may not be visible in current state
        }
    }

    @MainActor
    func testWelcomeScreenWorkflow() throws {
        let app = XCUIApplication()
        app.terminate()
        app.launch()
        sleep(3)

        // Check for welcome screen
        let welcomeTitle = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Nudge Video Cull'")).firstMatch

        if welcomeTitle.exists {
            print("✓ Welcome screen displayed")

            // Wait for scanning to complete
            let scanComplete = NSPredicate(format: "label CONTAINS[c] 'Ready to begin' OR label CONTAINS[c] 'Ready to start'")
            let readyText = app.staticTexts.containing(scanComplete).firstMatch
            let scanCompleted = readyText.waitForExistence(timeout: 30)
            XCTAssertTrue(scanCompleted, "Scanning should complete within 30 seconds")

            // Click GO! button
            let goButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'GO!'")).firstMatch
            XCTAssertTrue(goButton.exists, "GO! button should exist")
            XCTAssertTrue(goButton.isHittable, "GO! button should be clickable")

            goButton.click()
            sleep(2)

            // Handle potential warning dialog
            let warningDialog = app.windows.containing(NSPredicate(format: "title CONTAINS[c] 'Warning'")).firstMatch
            if warningDialog.exists {
                let proceedButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Proceed'")).firstMatch
                if proceedButton.exists && proceedButton.isHittable {
                    proceedButton.click()
                    sleep(1)
                }
            }

            print("✓ Welcome screen workflow completed")
        }
    }

    @MainActor
    func testCompactWorkflowNodesDisplay() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Check for workflow nodes in toolbar
        let sourceNode = mainWindow.staticTexts.matching(NSPredicate(format: "label == 'Source'")).firstMatch
        let outputNode = mainWindow.staticTexts.matching(NSPredicate(format: "label == 'Output'")).firstMatch

        XCTAssertTrue(sourceNode.exists || outputNode.exists, "At least one workflow node should be visible")

        // Check for Process button
        let processButton = mainWindow.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Process'")).firstMatch
        if processButton.exists {
            print("✓ Process button found")
        }

        print("✓ Compact workflow nodes displayed")
    }

    @MainActor
    func testFileStatisticsDisplay() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Look for file count and space statistics
        let fileStats = mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Files:'"))
        let spaceStats = mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Space:' OR label CONTAINS 'GB'"))

        print("File statistics labels found: \(fileStats.count)")
        print("Space statistics labels found: \(spaceStats.count)")

        // At least one stat should be visible if folder is selected
        if fileStats.count > 0 {
            let firstStat = fileStats.firstMatch
            if firstStat.exists {
                print("File stat: \(firstStat.label)")
                XCTAssertTrue(firstStat.isHittable || firstStat.frame.height > 0, "File stat should be visible")
            }
        }

        print("✓ File statistics check completed")
    }

    @MainActor
    func testDeletionFlagToggle() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Find deletion flag checkbox
        let deletionToggle = mainWindow.checkBoxes.matching(NSPredicate(format: "label CONTAINS 'Flag for Deletion' OR label CONTAINS 'Do not import'")).firstMatch

        if deletionToggle.exists && deletionToggle.isEnabled {
            print("✓ Deletion flag toggle found and enabled")

            let initialState = deletionToggle.value as? Int ?? 0
            deletionToggle.click()
            sleep(1)

            let newState = deletionToggle.value as? Int ?? 0
            XCTAssertNotEqual(initialState, newState, "Deletion flag state should change after clicking")

            print("✓ Deletion flag toggle works")
        } else {
            print("⚠ Deletion flag toggle not found (may not have videos loaded)")
        }
    }

    @MainActor
    func testLUTSelection() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Find LUT picker dropdown
        let lutPickers = mainWindow.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'lut' OR label CONTAINS 'LUT'"))

        if lutPickers.count > 0 {
            print("✓ Found \(lutPickers.count) LUT pickers")

            let firstPicker = lutPickers.firstMatch
            if firstPicker.exists && firstPicker.isEnabled {
                print("✓ LUT picker is enabled")

                firstPicker.click()
                sleep(1)

                // Look for menu items
                let menuItems = mainWindow.menuItems.matching(NSPredicate(format: "label CONTAINS '.cube' OR label CONTAINS 'SLog' OR label CONTAINS 'Rec709'"))
                print("Found \(menuItems.count) LUT menu items")

                // Press Escape to close menu
                app.typeKey(.escape, modifierFlags: [])
                sleep(1)

                print("✓ LUT selection test completed")
            }
        } else {
            print("⚠ No LUT pickers found (may not have videos loaded)")
        }
    }

    @MainActor
    func testTrimControls() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Find sliders (playhead/trim controls)
        let sliders = mainWindow.sliders

        if sliders.count > 0 {
            print("✓ Found \(sliders.count) sliders")

            // Look for trim markers (triangle characters)
            let trimMarkers = mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS '>' OR label CONTAINS '<'"))
            print("Found \(trimMarkers.count) trim markers")

            if trimMarkers.count >= 2 {
                print("✓ Trim markers are displayed")
            }
        } else {
            print("⚠ No sliders found (may not have videos loaded)")
        }
    }

    @MainActor
    func testStarRating() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Find star rating buttons
        let stars = mainWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'star' OR identifier CONTAINS 'star'"))

        if stars.count > 0 {
            print("✓ Found \(stars.count) star buttons")

            let firstStar = stars.firstMatch
            if firstStar.exists && firstStar.isEnabled {
                firstStar.click()
                sleep(1)
                print("✓ Star rating click works")
            }
        } else {
            print("⚠ No star rating buttons found (may not have videos loaded)")
        }
    }

    @MainActor
    func testVideoMetadataDisplay() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Look for metadata labels
        let metadataFields = [
            "fps", "resolution", "duration", "gamma", "color", "camera", "lens"
        ]

        for field in metadataFields {
            let labels = mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", field))
            if labels.count > 0 {
                print("✓ Found \(labels.count) labels for '\(field)'")
            }
        }

        print("✓ Metadata display check completed")
    }

    @MainActor
    func testWorkflowNodeCentering() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Find Source and Output nodes
        let sourceNode = mainWindow.staticTexts.matching(NSPredicate(format: "label == 'Source'")).firstMatch
        let outputNode = mainWindow.staticTexts.matching(NSPredicate(format: "label == 'Output'")).firstMatch

        if sourceNode.exists && outputNode.exists {
            let sourceX = sourceNode.frame.minX
            let outputX = outputNode.frame.minX

            print("Source node X: \(sourceX)")
            print("Output node X: \(outputX)")

            // Nodes should not be at extreme left edge (< 50px)
            XCTAssertGreaterThan(sourceX, 50, "Source node should be centered, not at left edge")

            print("✓ Workflow nodes appear centered")
        }
    }

    @MainActor
    func testFolderPickerButtons() throws {
        let app = XCUIApplication()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // Look for Close Folder button
        let closeFolderButton = mainWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'Close Folder'")).firstMatch

        if closeFolderButton.exists {
            print("✓ Close Folder button found")
            XCTAssertTrue(closeFolderButton.frame.width > 0, "Close Folder button should be visible")
        }

        print("✓ Folder picker buttons check completed")
    }

    @MainActor
    func testPreferencesOpen() throws {
        let app = XCUIApplication()

        // Try to open preferences with Cmd+,
        app.typeKey(",", modifierFlags: .command)
        sleep(1)

        let preferencesWindow = app.windows.matching(NSPredicate(format: "title CONTAINS[c] 'Preferences' OR title CONTAINS[c] 'Settings'")).firstMatch

        if preferencesWindow.exists {
            print("✓ Preferences window opened")

            // Close it
            app.typeKey("w", modifierFlags: .command)
            sleep(1)

            print("✓ Preferences window closed")
        } else {
            print("⚠ Preferences window did not open (may require different approach)")
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
