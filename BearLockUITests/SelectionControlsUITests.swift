import XCTest

final class SelectionControlsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDurationPresetsAndModeReflectCurrentValue() throws {
        let app = launchApprovedSeededApp()
        let picker = app.segmentedControls["lock-composer-mode-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.buttons["Now"].isSelected)
        XCTAssertFalse(picker.buttons["In"].isSelected)
        XCTAssertTrue(app.buttons["duration-preset-120"].isSelected)
        XCTAssertFalse(app.buttons["duration-preset-30"].isSelected)
        selectionScreenshot(app, "duration-initial")

        let thirty = app.buttons["duration-preset-30"]
        assertUsable(thirty, in: app)
        thirty.tap()
        XCTAssertTrue(thirty.isSelected)
        XCTAssertFalse(app.buttons["duration-preset-120"].isSelected)
        XCTAssertEqual(app.sliders["duration-slider"].label, "Duration")
        XCTAssertEqual(app.sliders["duration-slider"].value as? String, "30 min")
        selectionScreenshot(app, "duration-selected")

        app.sliders["duration-slider"].adjust(toNormalizedSliderPosition: 0.4)
        for preset in [15, 30, 60, 120] {
            XCTAssertFalse(app.buttons["duration-preset-\(preset)"].isSelected)
        }
        selectionScreenshot(app, "duration-custom")
        selectMode("In", in: app)
        XCTAssertTrue(picker.buttons["In"].isSelected)
        XCTAssertFalse(picker.buttons["Now"].isSelected)
        selectionScreenshot(app, "mode-delayed")
    }

    func testWeekdaySelectionAndEditorSaveAgree() throws {
        let app = launchApprovedSeededApp()
        selectMode("Repeat", in: app)
        let sunday = app.buttons["weekday-1"]
        let monday = app.buttons["weekday-2"]
        XCTAssertFalse(sunday.isSelected)
        XCTAssertTrue(monday.isSelected)
        assertUsable(sunday, in: app)
        sunday.tap()
        monday.tap()
        XCTAssertTrue(sunday.isSelected)
        XCTAssertFalse(monday.isSelected)
        XCTAssertEqual(sunday.label, "Sunday")
        selectionScreenshot(app, "weekday-changed")
        for day in 1...7 {
            let button = app.buttons["weekday-\(day)"]
            if button.isSelected { button.tap() }
        }
        XCTAssertFalse(app.buttons["lock-composer-primary-button"].isEnabled)
        selectionScreenshot(app, "weekday-empty")
        sunday.tap()
        XCTAssertTrue(app.buttons["lock-composer-primary-button"].isEnabled)
        app.terminate()

        let editorApp = launchApprovedSeededApp(extraArguments: ["--ui-testing-disabled-recurring"])
        let edit = editorApp.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        scrollToButton(edit, in: editorApp)
        edit.tap()
        XCTAssertTrue(editorApp.navigationBars["Repeat"].waitForExistence(timeout: 5))
        editorApp.buttons["weekday-1"].tap()
        editorApp.buttons["weekday-2"].tap()
        selectionScreenshot(editorApp, "weekday-editor-changed")
        editorApp.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        scrollToButton(edit, in: editorApp)
        edit.tap()
        XCTAssertTrue(editorApp.buttons["weekday-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(editorApp.buttons["weekday-1"].isSelected)
        XCTAssertFalse(editorApp.buttons["weekday-2"].isSelected)
        selectionScreenshot(editorApp, "weekday-editor-saved")
    }

    func testSelectionAtAccessibilityTextSizeInEnglishAndJapanese() throws {
        for (locale, repeatTitle, sundayName) in [("en", "Repeat", "Sunday"), ("ja", "繰り返し", "日曜日")] {
            let app = launchApprovedSeededApp(extraArguments: [
                "-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ja" ? "ja_JP" : "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ])
            XCTAssertTrue(app.buttons["duration-preset-120"].waitForExistence(timeout: 10))
            let thirty = app.buttons["duration-preset-30"]
            assertUsable(thirty, in: app)
            thirty.tap()
            XCTAssertTrue(thirty.isSelected)
            selectionScreenshot(app, "accessibility-\(locale)-duration")
            selectMode(repeatTitle, in: app)
            let sunday = app.buttons["weekday-1"]
            assertUsable(sunday, in: app)
            XCTAssertEqual(sunday.label, sundayName)
            sunday.tap()
            XCTAssertTrue(sunday.isSelected)
            selectionScreenshot(app, "accessibility-\(locale)-weekdays-top")
            let saturday = app.buttons["weekday-7"]
            assertUsable(saturday, in: app)
            saturday.tap()
            XCTAssertTrue(saturday.isSelected)
            selectionScreenshot(app, "accessibility-\(locale)-weekdays-bottom")
            let create = app.buttons["lock-composer-primary-button"]
            assertUsable(create, in: app)
            XCTAssertTrue(create.isEnabled)
            app.terminate()
        }
    }

    func testDisabledControlsRemainUnderstandable() throws {
        let app = launchApprovedSeededApp()
        selectMode("In", in: app)
        let decrease = app.buttons["Decrease start delay"]
        for _ in 0..<5 { decrease.tap() }
        XCTAssertFalse(decrease.isEnabled)
        XCTAssertTrue(app.buttons["Increase start delay"].isEnabled)
        selectionScreenshot(app, "delay-minimum")
        app.terminate()

        let locked = launchApprovedSeededApp(extraArguments: ["--ui-testing-active-recurring", "--ui-testing-all-day-recurring"])
        XCTAssertTrue(locked.staticTexts["locked-target-explanation"].waitForExistence(timeout: 10))
        XCTAssertFalse(locked.buttons["Select targets"].exists)
        XCTAssertFalse(locked.segmentedControls["lock-composer-mode-picker"].buttons["Now"].exists)
        selectionScreenshot(locked, "locked-target-explanation")
        let delete = locked.buttons.matching(identifier: "scheduled-lock-delete-button").firstMatch
        scrollToButton(delete, in: locked)
        let edit = locked.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch
        XCTAssertFalse(edit.isEnabled)
        XCTAssertTrue(delete.isEnabled)
        XCTAssertGreaterThanOrEqual(edit.frame.width, 44)
        XCTAssertGreaterThanOrEqual(delete.frame.height, 44)
        selectionScreenshot(locked, "locked-schedule-actions")
    }

    private func selectMode(_ title: String, in app: XCUIApplication) {
        let segmented = app.segmentedControls["lock-composer-mode-picker"]
        if segmented.exists {
            let button = segmented.buttons[title]
            scrollToButton(button, in: app)
            button.tap()
        } else {
            let menu = app.buttons["lock-composer-mode-picker"]
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            scrollToButton(menu, in: app)
            menu.tap()
            let choice = app.buttons[title]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
        }
    }

    private func assertUsable(_ button: XCUIElement, in app: XCUIApplication) {
        scrollToButton(button, in: app)
        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
    }

    private func selectionScreenshot(_ app: XCUIApplication, _ state: String) {
        captureScreenshot(named: "selection-\(Int(app.frame.width))-\(state)")
    }
}
