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
}
