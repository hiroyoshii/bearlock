import XCTest

final class SelectionControlsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDateAndTimeButtonsOpenIndependently() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLocale", "en_US"])
        selectComposerMode("Date & Time", in: app)
        let picker = app.datePickers.firstMatch
        let parts = picker.buttons.allElementsBoundByIndex.filter { $0.buttons.count == 0 }
        XCTAssertEqual(parts.count, 2)
        let before = picker.buttons["Date and Time Picker"].value as? String
        parts[0].tap()
        let dismiss = app.buttons["PopoverDismissRegion"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        XCTAssertEqual(app.pickerWheels.count, 0)
        selectionScreenshot(app, "calendar-open")
        dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()
        XCTAssertEqual(picker.buttons["Date and Time Picker"].value as? String, before)
        parts[1].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        let hour = app.pickerWheels.element(boundBy: 0)
        let newHour = (hour.value as? String)?.hasPrefix("3 ") == true ? "4" : "3"
        hour.adjust(toPickerWheelValue: newHour)
        selectionScreenshot(app, "time-open")
        dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()
        XCTAssertFalse(app.pickerWheels.firstMatch.exists)
        XCTAssertNotEqual(picker.buttons["Date and Time Picker"].value as? String, before)
        selectionScreenshot(app, "time-changed")
    }

    func testJapaneseNormalControlsAndFixedDateFlow() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"])
        for title in ["今すぐ", "後で", "日時指定", "繰り返し"] {
            selectComposerMode(title, in: app)
            let create = app.buttons["lock-composer-primary-button"]
            scrollToButton(create, in: app)
            create.tap()
            XCTAssertTrue(app.buttons["lock-confirmation-confirm-button"].waitForExistence(timeout: 5))
            selectionScreenshot(app, "normal-ja-\(title)-confirmation")
            app.buttons["キャンセル"].tap()
            XCTAssertFalse(app.buttons["lock-confirmation-confirm-button"].exists)
        }
        assertWeekdaysShareOneRow(in: app)
        let sunday = app.buttons["weekday-1"]
        sunday.tap()
        XCTAssertTrue(sunday.isSelected)
        XCTAssertEqual(sunday.label, "日曜日")
        selectionScreenshot(app, "normal-ja-weekdays")

        selectComposerMode("日時指定", in: app)
        app.buttons["lock-composer-primary-button"].tap()
        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch.waitForExistence(timeout: 10))
        let edit = app.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch
        scrollToButton(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.navigationBars["ロック予定を編集"].waitForExistence(timeout: 5))
        selectionScreenshot(app, "normal-ja-fixed-date-editor")
        app.buttons["保存"].tap()
        let delete = app.buttons.matching(identifier: "scheduled-lock-delete-button").firstMatch
        scrollToButton(delete, in: app)
        delete.tap()
        XCTAssertTrue(app.buttons["削除"].waitForExistence(timeout: 5))
        app.buttons["削除"].tap()
        XCTAssertTrue(app.staticTexts["予定されたロックはありません。"].waitForExistence(timeout: 5))
        selectionScreenshot(app, "normal-ja-fixed-date-deleted")
    }

    func testDurationPresetsAndModeReflectCurrentValue() throws {
        let app = launchApprovedSeededApp()
        let picker = app.segmentedControls["lock-composer-mode-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.buttons["Now"].isSelected)
        XCTAssertFalse(picker.buttons["In"].isSelected)
        XCTAssertTrue(picker.buttons["Date & Time"].exists)
        for title in ["Now", "In", "Date & Time", "Always"] {
            let button = picker.buttons[title]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 28, "Keep the native segmented control sizing")
            XCTAssertEqual(button.frame.midY, picker.buttons["Now"].frame.midY, accuracy: 1)
        }
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
        selectComposerMode("In", in: app)
        XCTAssertTrue(picker.buttons["In"].isSelected)
        XCTAssertFalse(picker.buttons["Now"].isSelected)
        selectionScreenshot(app, "mode-delayed")
    }

    func testFourComposerModesAndRepeatChoicesInsideDateTime() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        let picker = app.segmentedControls["lock-composer-mode-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        captureScreenshot(named: "four-lock-modes-en")
        for title in ["Now", "In", "Date & Time", "Always"] {
            XCTAssertTrue(picker.buttons[title].exists, "Missing composer mode \(title)")
        }
        XCTAssertFalse(picker.buttons["Repeat"].exists)

        selectComposerMode("Date & Time", in: app)
        let repeatPicker = app.segmentedControls["date-repeat-picker"]
        XCTAssertTrue(repeatPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(repeatPicker.buttons["None"].isSelected)
        XCTAssertFalse(app.buttons["weekday-1"].exists)

        repeatPicker.buttons["Weekdays"].tap()
        XCTAssertTrue(app.buttons["weekday-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["weekday-2"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["repeat-start-time"].exists)
        XCTAssertTrue(app.buttons["duration-preset-120"].exists)
    }

    func testWeekdaySelectionAndEditorSaveAgree() throws {
        let app = launchApprovedSeededApp()
        selectComposerMode("Date & Time", in: app)
        app.segmentedControls["date-repeat-picker"].buttons["Weekdays"].tap()
        let sunday = app.buttons["weekday-1"]
        let monday = app.buttons["weekday-2"]
        XCTAssertFalse(sunday.isSelected)
        XCTAssertTrue(monday.isSelected)
        assertWeekdaysShareOneRow(in: app)
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
        assertWeekdaysShareOneRow(in: editorApp)
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
        assertWeekdaysShareOneRow(in: editorApp)
        selectionScreenshot(editorApp, "weekday-editor-saved")
    }

    func testAlwaysLockSetupAndAllowanceUseTheConfiguredList() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        selectComposerMode("Always", in: app)
        XCTAssertTrue(app.buttons["Start Always Lock"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["daily-allowance-selected-limit"].exists)
        XCTAssertFalse(app.buttons["weekday-1"].exists)
        XCTAssertFalse(app.buttons["Select always-lock apps"].exists)
        captureScreenshot(named: "always-settings-after")
        app.buttons["Start Always Lock"].tap()
        let row = app.staticTexts["always-lock-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["daily-allowance-balance"].label.contains("60 min remaining"))
        XCTAssertTrue(app.buttons["always-lock-edit-button"].exists)
        XCTAssertTrue(app.staticTexts["Configured"].exists)
        XCTAssertFalse(app.buttons["Start Always Lock"].exists)
        let fiveMinutes = app.buttons["5 min unlock"]
        XCTAssertTrue(fiveMinutes.waitForExistence(timeout: 5))
        scrollToButton(fiveMinutes, in: app)
        captureScreenshot(named: "always-configured-row-after")
        fiveMinutes.tap()
        XCTAssertTrue(app.staticTexts["Temporarily unlocked"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["daily-allowance-balance"].label.contains("55 min remaining"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Relocks at")).firstMatch.exists)
        app.buttons["End temporary unlock"].tap()
        let returnedBalance = app.staticTexts["daily-allowance-balance"]
        XCTAssertTrue(returnedBalance.waitForExistence(timeout: 5))
        XCTAssertNotEqual(returnedBalance.label, "55 min remaining")
        captureScreenshot(named: "always-early-end-return")
    }

    func testPaidTimedUnlockUsesSeparateDurationSheet() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"])
        app.segmentedControls["lock-composer-mode-picker"].buttons.element(boundBy: 3).tap()
        app.buttons["lock-composer-primary-button"].tap()

        let paidUnlock = app.buttons["daily-allowance-paid-unlock-button"]
        XCTAssertTrue(paidUnlock.waitForExistence(timeout: 10))
        scrollToButton(paidUnlock, in: app)
        XCTAssertEqual(paidUnlock.label, "時間を指定して解除")
        captureScreenshot(named: "always-paid-unlock-entry-ja")
        paidUnlock.tap()

        XCTAssertTrue(app.navigationBars["時間指定で解除"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["paid-daily-unlock-duration-minutes"].value as? String, "30")
        XCTAssertTrue(app.staticTexts["購入による解除は今日の解除枠を消費せず、指定時刻に常時ロックへ戻ります。"].exists)
        let purchase = app.buttons["paid-daily-unlock-confirm"]
        XCTAssertTrue(purchase.isEnabled)
        XCTAssertTrue(purchase.label.contains("¥500"))
        captureScreenshot(named: "always-paid-unlock-duration-ja")
    }

    func testAlwaysLockEditSchedulesChangesAndStopForTomorrow() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        selectComposerMode("Always", in: app)
        app.buttons["Start Always Lock"].tap()
        let edit = app.buttons["always-lock-edit-button"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        scrollToButton(edit, in: app)
        edit.tap()

        let inlineEditorTitle = app.staticTexts["daily-allowance-inline-editor-title"]
        XCTAssertTrue(inlineEditorTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Edit Always Lock"].exists)
        XCTAssertFalse(app.switches["Enabled"].exists)
        XCTAssertFalse(app.buttons["weekday-1"].exists)
        XCTAssertTrue(app.buttons["daily-allowance-stop"].exists)
        XCTAssertTrue(app.staticTexts["daily-allowance-effective-date"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Today's lock remains active")).firstMatch.exists)
        captureScreenshot(named: "always-edit-inline")

        let limitPicker = app.descendants(matching: .any)["daily-allowance-edit-limit-picker"]
        XCTAssertTrue(limitPicker.exists)
        limitPicker.tap()
        let thirty = app.buttons["30 minutes"]
        XCTAssertTrue(thirty.waitForExistence(timeout: 5))
        thirty.tap()
        app.buttons["daily-allowance-save-changes"].tap()

        XCTAssertTrue(app.staticTexts["daily-allowance-balance"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["daily-allowance-balance"].label.contains("60 min remaining"))
        XCTAssertTrue(app.staticTexts["Tomorrow: daily limit 30 min"].exists)
        captureScreenshot(named: "always-pending-change")

        edit.tap()
        XCTAssertTrue(app.staticTexts["daily-allowance-inline-editor-title"].waitForExistence(timeout: 5))
        app.buttons["daily-allowance-stop"].tap()
        XCTAssertTrue(app.staticTexts["daily-allowance-balance"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Tomorrow: stopped"].exists)
        XCTAssertTrue(app.buttons["daily-allowance-grant-5"].exists)
    }

    func testAlwaysLockJapaneseSettingsAndConfiguredListScreenshots() throws {
        let app = launchApprovedSeededApp(extraArguments: ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"])
        let modePicker = app.segmentedControls["lock-composer-mode-picker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 10))
        modePicker.buttons.element(boundBy: 3).tap()
        let overview = app.staticTexts["daily-allowance-overview"]
        let selectedLimit = app.staticTexts["daily-allowance-selected-limit"]
        XCTAssertTrue(overview.exists)
        XCTAssertLessThan(overview.frame.minY, selectedLimit.frame.minY)
        XCTAssertGreaterThanOrEqual(overview.frame.minY, modePicker.frame.maxY)
        captureScreenshot(named: "always-settings-after-ja")
        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["daily-allowance-balance"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["daily-allowance-balance"].label, "今日の解除枠：残り60分")
        let edit = app.buttons["always-lock-edit-button"]
        scrollToButton(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.staticTexts["daily-allowance-inline-editor-title"].waitForExistence(timeout: 5))
        captureScreenshot(named: "always-edit-inline-ja")
        app.buttons["キャンセル"].tap()
        let grantButton = app.buttons["daily-allowance-grant-5"]
        scrollToButton(grantButton, in: app)
        app.swipeUp()
        XCTAssertFalse(app.staticTexts["対象：3件の対象"].exists)
        XCTAssertTrue(app.staticTexts["早めにロックすると、残り時間の満1分単位を解除枠に戻します。"].exists)
        captureScreenshot(named: "always-configured-row-after-ja")
    }

    func testWokenRecurringEditorAllowsChangesBeforeOriginalEnd() throws {
        let app = launchApprovedSeededApp(extraArguments: [
            "--ui-testing-active-recurring", "--ui-testing-woken-recurring"
        ])
        let edit = app.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        scrollToButton(edit, in: app)
        XCTAssertTrue(edit.isEnabled)
        edit.tap()
        XCTAssertTrue(app.navigationBars["Repeat"].waitForExistence(timeout: 5))
        let enabled = app.switches["recurring-rule-enabled-toggle"]
        XCTAssertTrue(enabled.isEnabled)
        XCTAssertTrue(app.buttons["weekday-1"].isEnabled)
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        tapSwitch(app, identifier: "recurring-rule-enabled-toggle", label: "Enabled")
        app.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        scrollToButton(edit, in: app)
        edit.tap()
        XCTAssertTrue(enabled.waitForExistence(timeout: 5))
        XCTAssertEqual(enabled.value as? String, "0")
    }

    func testSelectionAtAccessibilityTextSizeInEnglishAndJapanese() throws {
        for (locale, weekdaysTitle, dateTitle, sundayName, cancelTitle, saveTitle) in [("en", "Weekdays", "Date & Time", "Sunday", "Cancel", "Save"), ("ja", "曜日指定", "日時指定", "日曜日", "キャンセル", "保存")] {
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
            selectComposerMode(dateTitle, in: app)
            XCTAssertTrue(app.segmentedControls["date-repeat-picker"].exists)
            selectionScreenshot(app, "accessibility-\(locale)-date")
            let repeatPicker = app.segmentedControls["date-repeat-picker"]
            XCTAssertTrue(repeatPicker.waitForExistence(timeout: 5))
            repeatPicker.buttons[weekdaysTitle].tap()
            selectionScreenshot(app, "accessibility-\(locale)-repeat-mode")
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
            XCTAssertTrue(app.descendants(matching: .any)["repeat-start-time"].exists)
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
        let english = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        let app = launchApprovedSeededApp(extraArguments: english)
        selectComposerMode("In", in: app)
        let decrease = app.buttons["Decrease start delay"]
        for _ in 0..<5 { decrease.tap() }
        XCTAssertFalse(decrease.isEnabled)
        XCTAssertTrue(app.buttons["Increase start delay"].isEnabled)
        selectionScreenshot(app, "delay-minimum")
        app.terminate()

        let locked = launchApprovedSeededApp(extraArguments: english + ["--ui-testing-active-recurring", "--ui-testing-all-day-recurring"])
        XCTAssertTrue(locked.staticTexts["locked-target-explanation"].waitForExistence(timeout: 10))
        XCTAssertFalse(locked.buttons["Select targets"].exists)
        let modes = locked.segmentedControls["lock-composer-mode-picker"]
        XCTAssertTrue(modes.exists)
        XCTAssertTrue(modes.buttons["In"].exists)
        XCTAssertTrue(modes.buttons["Now"].exists)
        selectComposerMode("Now", in: locked)
        XCTAssertFalse(locked.buttons["lock-composer-primary-button"].isEnabled)
        XCTAssertTrue(locked.staticTexts["Cannot start now while a lock is active."].exists)
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

    private func assertWeekdaysShareOneRow(in app: XCUIApplication) {
        let first = app.buttons["weekday-1"]
        scrollToButton(first, in: app)
        let firstFrame = first.frame
        var previousMaxX = app.frame.minX
        for day in 1...7 {
            let button = app.buttons["weekday-\(day)"]
            // Narrow rows share the available width; keep 44pt height and
            // check the 28pt minimum separately from the default 44pt target.
            assertUsable(button, in: app, minimumWidth: 28)
            XCTAssertEqual(button.frame.midY, firstFrame.midY, accuracy: 1, "All seven weekdays must stay on one row")
            XCTAssertEqual(button.frame.width, firstFrame.width, accuracy: 1, "Weekdays must share the available width equally")
            XCTAssertGreaterThanOrEqual(button.frame.minX, previousMaxX, "Weekday touch regions must not overlap")
            previousMaxX = button.frame.maxX
        }
    }

    private func assertUsable(_ button: XCUIElement, in app: XCUIApplication, minimumWidth: CGFloat = 44) {
        scrollToButton(button, in: app)
        XCTAssertGreaterThanOrEqual(button.frame.width, minimumWidth)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
    }

    private func selectionScreenshot(_ app: XCUIApplication, _ state: String) {
        captureScreenshot(named: "selection-\(Int(app.frame.width))-\(state)")
    }
}
