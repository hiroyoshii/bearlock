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
        XCTAssertTrue(picker.buttons[app.frame.width <= 375 ? "Date" : "Date & Time"].exists)
        XCTAssertTrue(app.buttons["duration-preset-120"].isSelected)
        XCTAssertFalse(app.buttons["duration-preset-30"].isSelected)
        selectionScreenshot(app, "duration-initial")

        let thirty = app.buttons["duration-preset-30"]
        assertUsable(thirty, in: app)
        XCTAssertLessThanOrEqual(thirty.frame.height, 56, "Normal-size presets should remain compact native buttons")
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
            if button.isSelected {
                scrollToButton(button, in: app)
                button.tap()
            }
        }
        XCTAssertFalse(app.buttons["lock-composer-primary-button"].isEnabled)
        selectionScreenshot(app, "weekday-empty")
        scrollToButton(sunday, in: app)
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
        for (locale, repeatTitle, dateTitle, sundayName, cancelTitle, saveTitle) in [("en", "Repeat", "Date & Time", "Sunday", "Cancel", "Save"), ("ja", "繰り返し", "日時指定", "日曜日", "キャンセル", "保存")] {
            let accessibilityArguments = [
                "-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "ja" ? "ja_JP" : "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
            let app = launchApprovedSeededApp(extraArguments: accessibilityArguments)
            XCTAssertTrue(app.buttons["duration-preset-120"].waitForExistence(timeout: 10))
            let thirty = app.buttons["duration-preset-30"]
            assertUsable(thirty, in: app)
            thirty.tap()
            XCTAssertTrue(thirty.isSelected)
            selectionScreenshot(app, "accessibility-\(locale)-duration")
            selectMode(dateTitle, in: app)
            XCTAssertTrue(app.staticTexts["schedule-date-label-Starts"].waitForExistence(timeout: 5))
            assertDateLabelsAreReadable(in: app, titles: ["Starts"])
            selectionScreenshot(app, "accessibility-\(locale)-date")
            selectMode(repeatTitle, in: app)
            selectionScreenshot(app, "accessibility-\(locale)-repeat-mode")
            let sunday = app.buttons["weekday-1"]
            XCTAssertTrue(sunday.waitForExistence(timeout: 5))
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
            assertDateLabelsAreReadable(in: app, titles: ["Starts", "Ends"])
            selectionScreenshot(app, "accessibility-\(locale)-times")
            let create = app.buttons["lock-composer-primary-button"]
            assertUsable(create, in: app)
            XCTAssertTrue(create.isEnabled)
            create.tap()
            let confirm = app.buttons["lock-confirmation-confirm-button"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            assertUsable(confirm, in: app)
            let cancel = app.buttons[cancelTitle]
            assertUsable(cancel, in: app)
            selectionScreenshot(app, "accessibility-\(locale)-confirmation")
            cancel.tap()
            XCTAssertFalse(confirm.exists)
            app.terminate()

            let editorApp = launchApprovedSeededApp(extraArguments: accessibilityArguments + ["--ui-testing-disabled-recurring"])
            let edit = editorApp.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch
            XCTAssertTrue(edit.waitForExistence(timeout: 10))
            scrollToButton(edit, in: editorApp)
            edit.tap()
            let editorSunday = editorApp.buttons["weekday-1"]
            assertUsable(editorSunday, in: editorApp)
            editorSunday.tap()
            XCTAssertTrue(editorSunday.isSelected)
            assertDateLabelsAreReadable(in: editorApp, titles: ["Starts", "Ends"])
            selectionScreenshot(editorApp, "accessibility-\(locale)-editor-times")
            let save = editorApp.buttons[saveTitle]
            // A system toolbar item's AX frame is not its full touch region.
            // Verify the native action by saving and reading the persisted value.
            scrollToButton(save, in: editorApp)
            XCTAssertTrue(save.isEnabled)
            save.tap()
            XCTAssertTrue(edit.waitForExistence(timeout: 5))
            scrollToButton(edit, in: editorApp)
            edit.tap()
            assertUsable(editorSunday, in: editorApp)
            XCTAssertTrue(editorSunday.isSelected)
            selectionScreenshot(editorApp, "accessibility-\(locale)-editor-saved")
            editorApp.terminate()
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

    private func assertDateLabelsAreReadable(in app: XCUIApplication, titles: [String]) {
        for title in titles {
            let label = app.staticTexts["schedule-date-label-\(title)"]
            scrollToButton(label, in: app)
            XCTAssertTrue(label.waitForExistence(timeout: 5))
            XCTAssertLessThanOrEqual(label.frame.height, 100, "Date label must not break into multiple short fragments")
            XCTAssertGreaterThanOrEqual(label.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(label.frame.maxX, app.frame.maxX)
        }
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
            let hittable = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in choice.exists && choice.isHittable },
                object: choice
            )
            XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed)
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
