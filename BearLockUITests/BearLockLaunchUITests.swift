import Foundation
import XCTest

final class BearLockLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchSetupScreenAndCaptureScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.buttons["Allow Screen Time access"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Select targets"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "bearlock-setup-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testApprovedHomeWithoutSelectionShowsTargetPickerEntryPoint() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-approved",
            "--reset-ui-testing-state"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Select targets"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Select blocked apps first."].exists)
        XCTAssertTrue(app.buttons["Select targets"].exists)
    }

    func testCreateImmediateLockWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["3 targets"].exists)
        XCTAssertTrue(app.sliders["duration-slider"].exists)

        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Start this lock?"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-immediate-confirmation")

        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts["Bear is sleeping."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Do not wake the bear."].exists)
        captureScreenshot(named: "e2e-immediate-active-lock")
    }

    func testRecentTargetsSelectionFeedbackAndActions() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-target-picker"])
        let recentID = "16161616-1616-1616-1616-161616161616"
        let selectButton = app.buttons["frequent-target-select-\(recentID)"]
        let actionsButton = app.buttons["frequent-target-actions-\(recentID)"]

        captureScreenshot(named: "e2e-target-flow-home")

        app.buttons["Select targets"].tap()
        XCTAssertTrue(app.navigationBars["Select targets"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-target-picker-open")

        let messages = app.buttons["ui-testing-target-app-messages"]
        let video = app.buttons["ui-testing-target-app-video"]
        XCTAssertTrue(messages.waitForExistence(timeout: 5))
        messages.tap()
        video.tap()
        XCTAssertEqual(messages.value as? String, "Selected")
        XCTAssertEqual(video.value as? String, "Selected")
        captureScreenshot(named: "e2e-target-picker-apps-selected")

        let saveButton = app.buttons["ui-testing-target-save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        XCTAssertFalse(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 targets"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-target-flow-saved")

        let disclosure = app.buttons["target-list-disclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 10))
        XCTAssertFalse(selectButton.exists)
        disclosure.tap()

        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-target-flow-details")
        selectButton.tap()
        let selectedValue = NSPredicate(format: "value == %@", "Selected")
        expectation(for: selectedValue, evaluatedWith: selectButton)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["Selected"].exists)
        captureScreenshot(named: "e2e-target-flow-recent-selected")

        actionsButton.tap()
        XCTAssertTrue(app.buttons["Pin target"].waitForExistence(timeout: 5))
        app.buttons["Pin target"].tap()

        actionsButton.tap()
        XCTAssertTrue(app.buttons["Unpin target"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove target"].exists)
        app.buttons["Remove target"].tap()
        XCTAssertTrue(app.buttons["Remove"].waitForExistence(timeout: 5))
        app.buttons["Remove"].tap()
        XCTAssertFalse(selectButton.waitForExistence(timeout: 2))
        captureScreenshot(named: "e2e-target-flow-recent-deleted")
    }

    func testScheduleEditAndDeleteDelayedLockWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        app.buttons["In"].tap()
        XCTAssertTrue(app.staticTexts["Start delay"].waitForExistence(timeout: 5))
        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Schedule this lock?"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-delayed-confirmation")

        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts["Starts later"].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-delayed-scheduled")

        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertTrue(app.navigationBars["Edit Lock"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-delayed-editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Starts later"].waitForExistence(timeout: 10))

        tapFirstButton(app, identifier: "scheduled-lock-delete-button")
        XCTAssertTrue(app.staticTexts["No scheduled locks."].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-delayed-deleted")
    }

    func testCreateAndOpenRecurringEditorWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        app.buttons["Repeat"].tap()
        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Schedule this lock?"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-recurring-confirmation")

        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts["Repeats"].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-recurring-scheduled")

        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertTrue(app.navigationBars["Repeat"].waitForExistence(timeout: 5))
        tapSwitch(app, identifier: "recurring-rule-enabled-toggle", label: "Enabled")
        captureScreenshot(named: "e2e-recurring-disabled-editor")
        app.buttons["Cancel"].tap()
    }

    func testDisabledRecurringSeedShowsOffStateWithMockServices() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-disabled-recurring"])

        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        scrollToStaticText("Repeats", in: app)
        scrollToStaticText("Off", in: app)
        captureScreenshot(named: "e2e-recurring-disabled-list")
    }

    func testActiveLockHidesMutableControlsWithMockServices() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-active-lock"])

        XCTAssertTrue(app.staticTexts["Bear is sleeping."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Do not wake the bear."].exists)
        XCTAssertFalse(app.staticTexts["Now"].exists)
        XCTAssertTrue(app.buttons["lock-composer-primary-button"].exists)
        XCTAssertTrue(app.buttons["In"].exists)
        XCTAssertFalse(app.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(identifier: "scheduled-lock-delete-button").firstMatch.exists)
        captureScreenshot(named: "e2e-active-lock-constraints")
    }

    private func launchApprovedSeededApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-approved",
            "--ui-testing-seeded",
            "--reset-ui-testing-state"
        ] + extraArguments
        app.launch()
        return app
    }

    private func tapFirstButton(_ app: XCUIApplication, identifier: String) {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        if !button.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Expected button with identifier \(identifier)")
        button.tap()
    }

    private func tapSwitch(_ app: XCUIApplication, identifier: String, label: String) {
        let identifiedSwitch = app.switches.matching(identifier: identifier).firstMatch
        if identifiedSwitch.waitForExistence(timeout: 3) {
            identifiedSwitch.tap()
            return
        }

        let labeledSwitch = app.switches[label]
        XCTAssertTrue(labeledSwitch.waitForExistence(timeout: 5), "Expected switch with identifier \(identifier) or label \(label)")
        labeledSwitch.tap()
    }

    private func scrollToStaticText(_ text: String, in app: XCUIApplication) {
        let element = app.staticTexts[text]
        for _ in 0..<4 where !element.exists {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Expected static text \(text)")
    }

    private func captureScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        writeScreenshotIfRequested(screenshot, named: name)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func writeScreenshotIfRequested(_ screenshot: XCUIScreenshot, named name: String) {
        let directory = ProcessInfo.processInfo.environment["E2E_SCREENSHOT_DIR"] ?? "/tmp/bearlock-e2e-screenshots"

        do {
            let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directoryURL.appending(path: "\(name).png"))
        } catch {
            XCTFail("Failed to write e2e screenshot \(name): \(error)")
        }
    }
}
