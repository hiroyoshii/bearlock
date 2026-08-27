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

        XCTAssertTrue(app.staticTexts["Bear Lock"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Screen Timeアクセスを許可"].exists)
        XCTAssertTrue(app.buttons["ブロック対象アプリを選ぶ"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "bearlock-setup-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCreateImmediateLockWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.staticTexts["Distractions stay outside."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["SNS, Video, Games"].exists)

        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Bear will sleep now."].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-immediate-confirmation")

        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts["Bear is sleeping."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Do not wake the bear."].exists)
        captureScreenshot(named: "e2e-immediate-active-lock")
    }

    func testScheduleEditAndDeleteDelayedLockWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.staticTexts["Distractions stay outside."].waitForExistence(timeout: 10))
        app.buttons["In"].tap()
        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Schedule Bear's sleep."].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-delayed-confirmation")

        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts["Starts later"].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-delayed-scheduled")

        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertTrue(app.navigationBars["Edit Hibernation"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-delayed-editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Starts later"].waitForExistence(timeout: 10))

        tapFirstButton(app, identifier: "scheduled-lock-delete-button")
        XCTAssertTrue(app.staticTexts["予定された冬眠はありません。"].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-delayed-deleted")
    }

    private func launchApprovedSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-approved",
            "--ui-testing-seeded",
            "--reset-ui-testing-state"
        ]
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

    private func captureScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        writeScreenshotIfRequested(screenshot, named: name)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func writeScreenshotIfRequested(_ screenshot: XCUIScreenshot, named name: String) {
        guard let directory = ProcessInfo.processInfo.environment["E2E_SCREENSHOT_DIR"],
              !directory.isEmpty
        else {
            return
        }

        do {
            let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directoryURL.appending(path: "\(name).png"))
        } catch {
            XCTFail("Failed to write e2e screenshot \(name): \(error)")
        }
    }
}
