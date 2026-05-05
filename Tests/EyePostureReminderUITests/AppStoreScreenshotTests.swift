// AppStoreScreenshotTests.swift
// kshana UI Tests
//
// Targeted, opt-in screenshot capture for App Store submission assets.

import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let outputPath = ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_DIR"]
        outputDirectory = outputPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? defaultOutputDirectory
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        app = nil
        outputDirectory = nil
    }

    func test_captureAppStoreScreenshotSet() throws {
        try captureOnboardingWelcome()
        try captureSettingsView()
        try captureEyeBreakOverlay()
        try capturePostureCheckOverlay()
        try captureSnoozeOptions()
    }

    private func captureOnboardingWelcome() throws {
        launch(arguments: [TestLaunchArguments.resetOnboarding])
        XCTAssertTrue(app.buttons["onboarding.welcome.nextButton"].waitForExistence(timeout: 5))
        try capture("04-onboarding-welcome")
    }

    private func captureSettingsView() throws {
        launch(arguments: [TestLaunchArguments.skipOnboarding])
        openSettings()
        XCTAssertTrue(app.switches["settings.masterToggle"].waitForExistence(timeout: 5))
        try capture("01-settings")
    }

    private func captureEyeBreakOverlay() throws {
        launch(arguments: [TestLaunchArguments.showOverlayEyes])
        XCTAssertTrue(app.waitForOverlayPresented(timeout: 8))
        try capture("02-eye-break-overlay")
    }

    private func capturePostureCheckOverlay() throws {
        launch(arguments: [TestLaunchArguments.showOverlayPosture])
        XCTAssertTrue(app.waitForOverlayPresented(timeout: 8))
        try capture("03-posture-check-overlay")
    }

    private func captureSnoozeOptions() throws {
        launch(arguments: [TestLaunchArguments.skipOnboarding])
        openSettings()
        let snoozeButton = app.buttons["settings.snooze.5min"]
        scrollToElement(snoozeButton, maxSwipes: 4)
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 5))
        try capture("05-snooze-options")
    }

    private func launch(arguments: [String]) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func openSettings() {
        XCTAssertTrue(app.waitForHomeScreenReady(timeout: 12))
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(app.waitForElementHittable(settingsButton, timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.buttons["settings.doneButton"].waitForExistence(timeout: 5))
    }

    private func scrollToElement(_ element: XCUIElement, maxSwipes: Int) {
        for _ in 0...maxSwipes where !element.exists {
            app.swipeUp()
            _ = element.waitForExistence(timeout: 0.5)
        }
    }

    private func capture(_ basename: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let fileURL = outputDirectory.appendingPathComponent("\(basename).png")
        try screenshot.pngRepresentation.write(to: fileURL, options: .atomic)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = basename
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var defaultOutputDirectory: URL {
        repositoryRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("app-store-screenshots")
            .appendingPathComponent(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "Simulator")
    }

    private var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift").path
            ) {
                return url
            }
        }
        preconditionFailure("Cannot locate repo root from \(#filePath)")
    }
}
