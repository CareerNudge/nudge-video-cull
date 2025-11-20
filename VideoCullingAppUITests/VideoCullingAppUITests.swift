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

        // Find the gallery mode toggle button
        let galleryButton = app.buttons["galleryModeButton"]

        // Button should exist
        XCTAssertTrue(galleryButton.exists, "Gallery mode button should exist")

        // Verify button is hittable
        XCTAssertTrue(galleryButton.isHittable, "Gallery mode button should be clickable")

        // Click the button (should not crash)
        galleryButton.click()
        sleep(1)

        // App should still be running after toggle
        XCTAssertTrue(app.exists, "App should not crash after gallery toggle")

        // Toggle back
        galleryButton.click()
        sleep(1)

        // App should still be running
        XCTAssertTrue(app.exists, "App should not crash during second toggle")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
