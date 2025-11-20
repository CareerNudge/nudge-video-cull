//
//  VideoCullingAppUITests.swift
//  VideoCullingAppUITests
//
//  Created by Roman Wilson on 11/17/25.
//

import XCTest

final class VideoCullingAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Welcome screen is now enabled for these tests
        if let testMode = ProcessInfo.processInfo.environment["TEST_MODE"],
           let testInputPath = ProcessInfo.processInfo.environment["TEST_INPUT_PATH"],
           let testOutputPath = ProcessInfo.processInfo.environment["TEST_OUTPUT_PATH"] {
            app.launchEnvironment["TEST_MODE"] = testMode
            app.launchEnvironment["TEST_INPUT_PATH"] = testInputPath
            app.launchEnvironment["TEST_OUTPUT_PATH"] = testOutputPath
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    @MainActor
    func testEndToEndWorkflowAndCrashFixValidation() throws {
        let app = XCUIApplication()
        // No need to click buttons for folder selection and GO, as ContentViewModel now handles this automatically in test mode.
        // The WelcomeView will eventually dismiss itself.

        // 1. Wait for all files to load
        let videoGallery = app.scrollViews["videoGallery"]
        let galleryLoadedExpectation = expectation(for: NSPredicate(format: "cells.count > 0"), evaluatedWith: videoGallery)
        wait(for: [galleryLoadedExpectation], timeout: 60)

        // 2. Select a video and interact with TextFields to validate the crash fix
        let firstVideoCell = videoGallery.cells.firstMatch
        XCTAssert(firstVideoCell.waitForExistence(timeout: 10), "First video cell not found.")
        firstVideoCell.click()
        
        let renameField = app.textFields["renameTextField"]
        let keywordsField = app.textFields["keywordsTextField"]
        XCTAssert(renameField.waitForExistence(timeout: 5), "Rename text field not found.")
        XCTAssert(keywordsField.waitForExistence(timeout: 5), "Keywords text field not found.")

        renameField.click()
        renameField.typeText("Test-Rename-123")
        
        keywordsField.click()
        keywordsField.typeText("gemini, test, stable")

        // 3. Change orientation to Horizontal
        app.menuBars.menuItems["Preferences"].click()
        
        let preferencesWindow = app.windows["Preferences"]
        XCTAssert(preferencesWindow.waitForExistence(timeout: 5), "Preferences window did not open.")
        
        preferencesWindow.toolbars.buttons["Appearance"].click() 
        
        let orientationPicker = preferencesWindow.pickers["orientationPicker"]
        XCTAssert(orientationPicker.exists, "Orientation picker not found.")
        orientationPicker.buttons["Horizontal"].click()
        preferencesWindow.buttons[XCUIIdentifierCloseWindow].click()

        // 4. Find and interact with the gallery mode toggle button
        let galleryButton = app.buttons["galleryModeButton"]
        XCTAssert(galleryButton.waitForExistence(timeout: 5), "Gallery mode button should exist in horizontal mode")
        XCTAssert(galleryButton.isHittable, "Gallery mode button should be clickable")

        // 5. Toggle to vertical
        galleryButton.click()
        sleep(1) 
        XCTAssertFalse(galleryButton.exists, "Gallery mode button should not exist in vertical mode after toggling.")
    }
