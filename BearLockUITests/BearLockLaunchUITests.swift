import Foundation
import XCTest

final class BearLockLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testReadFailureKeepsRecoveryVisibleAndReloadRestoresSavedTargets() throws {
        let app = XCUIApplication()
        let base = ["--ui-testing", "--ui-testing-approved", "--ui-testing-target-summary"]
        app.launchArguments = base + ["--reset-ui-testing-state", "--ui-testing-seeded", "--ui-testing-read-failure"]
        app.launch()
        XCTAssertTrue(app.buttons["storage-retry"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Get started"].exists)
        XCTAssertFalse(app.buttons["lock-composer-primary-button"].exists)
        captureScreenshot(named: "e2e-recovery-storage-error")
        openNavigationLink(app.buttons["storage-diagnostics"], destinationTitle: "Diagnostics", in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["storage-retry"].exists)
        app.buttons["storage-retry"].tap()
        XCTAssertTrue(app.staticTexts["Saved data could not be read"].waitForExistence(timeout: 5))
        let errorAlert = app.alerts["Bear Lock"]
        if errorAlert.waitForExistence(timeout: 1) {
            errorAlert.buttons["OK"].tap()
        }
        app.terminate()
        // Remove the injected failure; keep the same persisted repository.
        app.launchArguments = base
        app.launch()
        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["storage-retry"].exists)
        XCTAssertEqual(app.staticTexts["selected-target-count"].label, "3 targets")
        captureScreenshot(named: "e2e-recovery-storage-restored")
    }

    func testMonitoringErrorSurvivesRetryAndNavigationUntilUpdateSucceeds() throws {
        let app = XCUIApplication()
        let base = ["--ui-testing", "--ui-testing-approved"]
        app.launchArguments = base + ["--reset-ui-testing-state", "--ui-testing-seeded", "--ui-testing-monitoring-failure"]
        app.launch()
        let retry = app.buttons["monitoring-retry"]
        let hasRetry = retry.waitForExistence(timeout: 10)
        captureScreenshot(named: "e2e-recovery-monitoring-initial")
        XCTAssertTrue(hasRetry, app.debugDescription)
        app.buttons["monitoring-retry"].tap()
        XCTAssertTrue(app.staticTexts["Monitoring could not be updated"].exists)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["monitoring-retry"].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-recovery-monitoring-error")
        app.terminate()
        app.launchArguments = base
        app.launch()
        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["monitoring-retry"].exists)
        captureScreenshot(named: "e2e-recovery-monitoring-restored")
    }

    func testLaunchSetupScreenAndCaptureScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-testing-state"]
        app.launch()

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Select targets"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "bearlock-setup-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testIntroductionAndContextualAccessFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-testing-state", "--ui-testing-target-picker"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        captureScreenshot(named: "onboarding-introduction-en")
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.buttons["Select targets"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Screen Time access"].exists)
        app.buttons["In"].tap()
        app.buttons["Select targets"].tap()
        XCTAssertTrue(app.alerts["Screen Time access"].waitForExistence(timeout: 5))
        captureScreenshot(named: "onboarding-access-explanation-en")
        app.alerts.buttons["Not now"].tap()
        XCTAssertTrue(app.staticTexts["Start delay"].exists)
        app.buttons["Select targets"].tap()
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["ui-testing-target-app-messages"].waitForExistence(timeout: 5))
        app.buttons["ui-testing-target-app-messages"].tap()
        app.buttons["ui-testing-target-save"].tap()
        XCTAssertTrue(app.staticTexts["Start delay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["lock-composer-primary-button"].isEnabled)
        captureScreenshot(named: "onboarding-home-ready-en")
        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.buttons["lock-confirmation-confirm-button"].waitForExistence(timeout: 5))
        captureScreenshot(named: "onboarding-confirmation-en")
        app.buttons["Cancel"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-testing-target-picker"]
        app.launch()
        XCTAssertTrue(app.buttons["Select targets"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Get started"].exists)
    }

    func testDeclinedAccessKeepsHomeUsable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-testing-state", "--ui-testing-target-picker", "--ui-testing-deny-authorization"]
        app.launch()
        app.buttons["Get started"].tap()
        app.buttons["Select targets"].tap()
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Screen Time access is unavailable. Blocking may not be active."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Get started"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        app.buttons["Select targets"].tap()
        XCTAssertTrue(app.alerts["Screen Time access"].waitForExistence(timeout: 5))
        app.alerts.buttons["Not now"].tap()
        captureScreenshot(named: "onboarding-access-declined-en")
    }

    func testUnavailableAccessKeepsRecoveryAndSettingsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-testing-state", "--ui-testing-seeded"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Screen Time access is unavailable. Blocking may not be active."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["lock-composer-primary-button"].isEnabled)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let errorAlert = app.alerts["Bear Lock"]
        if errorAlert.waitForExistence(timeout: 1) {
            errorAlert.buttons["OK"].tap()
        }
        openNavigationLink(app.buttons["diagnostics-link"], destinationTitle: "Diagnostics", in: app)
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

    func testSettingsShowsOptionalSupportScreen() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        scrollToStaticText("Support", in: app)
        app.buttons["settings-support-link"].tap()

        XCTAssertTrue(app.navigationBars["Support"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bear Lock is free to use. Please consider supporting its development."].exists)
        XCTAssertTrue(app.staticTexts["Coffee"].exists)
        XCTAssertTrue(app.staticTexts["Lunch"].exists)
        XCTAssertTrue(app.staticTexts["Dinner"].exists)
        XCTAssertFalse(app.buttons["support-purchase-coffee"].isEnabled)
        XCTAssertTrue(app.buttons["support-reload"].exists)
        app.buttons["support-reload"].tap()
        XCTAssertTrue(app.staticTexts["Support items are not available yet."].exists)
        captureScreenshot(named: "e2e-settings-support")
    }

    func testCreateImmediateLockWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForLabel(app.staticTexts["selected-target-count"], toEqual: "3 targets"))
        XCTAssertTrue(app.sliders["duration-slider"].exists)

        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Start this lock?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["After confirmation"].exists)
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
        XCTAssertTrue(waitForLabel(app.staticTexts["selected-target-count"], toEqual: "2 targets"))
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

    func testReusingTargetRefreshesHomeCountsDetailsAndConfirmation() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-target-summary"])
        let count = app.staticTexts["selected-target-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.label, "3 targets")
        app.buttons["target-list-disclosure"].tap()
        XCTAssertTrue(app.staticTexts["selected-target-detail-Messages"].exists)
        XCTAssertFalse(app.staticTexts["selected-target-detail-Books"].exists)
        captureScreenshot(named: "e2e-target-summary-before-reuse")

        let sleepTarget = app.buttons["frequent-target-select-16161616-1616-1616-1616-161616161616"]
        scrollToButton(sleepTarget, in: app)
        sleepTarget.tap()
        expectation(for: NSPredicate(format: "label == %@", "2 targets"), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["selected-target-detail-Books"].exists)
        XCTAssertTrue(app.staticTexts["selected-target-detail-Music"].exists)
        XCTAssertFalse(app.staticTexts["selected-target-detail-Messages"].exists)
        captureScreenshot(named: "e2e-target-summary-after-reuse")

        // Switch back without navigating away: the summary must refresh both ways.
        let initialTarget = app.buttons["frequent-target-select-15151515-1515-1515-1515-151515151515"]
        scrollToButton(initialTarget, in: app)
        initialTarget.tap()
        expectation(for: NSPredicate(format: "label == %@", "3 targets"), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["selected-target-detail-Messages"].exists)
        XCTAssertFalse(app.staticTexts["selected-target-detail-Books"].exists)
        scrollToButton(sleepTarget, in: app)
        sleepTarget.tap()
        expectation(for: NSPredicate(format: "label == %@", "2 targets"), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        scrollToButton(app.buttons["target-list-disclosure"], in: app)
        app.buttons["target-list-disclosure"].tap()
        let create = app.buttons["lock-composer-primary-button"]
        scrollToButton(create, in: app)
        create.tap()
        let confirmation = app.staticTexts["lock-confirmation-apps"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertEqual(confirmation.label, "2 targets")
        captureScreenshot(named: "e2e-target-summary-confirmation")
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
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No scheduled locks."].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-delayed-deleted")
    }

    func testCreateAndOpenRecurringEditorWithMockServices() throws {
        let app = launchApprovedSeededApp()

        XCTAssertTrue(app.buttons["lock-composer-primary-button"].waitForExistence(timeout: 10))
        app.buttons["Repeat"].tap()
        app.buttons["lock-composer-primary-button"].tap()
        XCTAssertTrue(app.staticTexts["Schedule this lock?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A wake-up ends only the current lock. Future repeating locks stay scheduled."].exists)
        let end = app.staticTexts["lock-confirmation-wakes"]
        XCTAssertTrue(end.exists)
        XCTAssertFalse(end.label.contains("after start"))
        XCTAssertTrue(end.label.contains("7:00"), "Expected configured end time, got \(end.label)")
        captureScreenshot(named: "e2e-recurring-confirmation")

        app.buttons["lock-confirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts["Repeats"].waitForExistence(timeout: 10))
        captureScreenshot(named: "e2e-recurring-scheduled")

        if !app.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch.isEnabled {
            XCTAssertTrue(app.staticTexts["This lock is active. Changes are available after it ends."].exists)
            return
        }
        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertTrue(app.navigationBars["Repeat"].waitForExistence(timeout: 5))
        tapSwitch(app, identifier: "recurring-rule-enabled-toggle", label: "Enabled")
        captureScreenshot(named: "e2e-recurring-disabled-editor")
        app.buttons["Cancel"].tap()
        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertEqual(app.switches["recurring-rule-enabled-toggle"].value as? String, "1")
        tapSwitch(app, identifier: "recurring-rule-enabled-toggle", label: "Enabled")
        app.buttons["Save"].tap()
        scrollToStaticText("Off", in: app)
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
        XCTAssertTrue(app.buttons["schedule-free-wake"].exists)
        XCTAssertTrue(app.buttons["purchase-immediate-wake"].exists)
        XCTAssertFalse(app.buttons["purchase-immediate-wake"].isEnabled)
        captureScreenshot(named: "e2e-active-lock-constraints")
    }

    func testFreeWakeCanBeScheduledAndCancelledWithMockServices() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-active-lock"])
        let schedule = app.buttons["schedule-free-wake"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 10))
        scrollToButton(schedule, in: app)
        schedule.tap()
        app.buttons["Start 30-minute wake-up"].tap()

        let cancel = app.buttons["cancel-free-wake"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    }

    func testDisabledRecurringDraftCancelsWithoutChangingSavedStatus() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-disabled-recurring"])
        scrollToStaticText("Repeats", in: app)
        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertTrue(app.navigationBars["Repeat"].waitForExistence(timeout: 5))
        tapSwitch(app, identifier: "recurring-rule-enabled-toggle", label: "Enabled")
        app.buttons["Cancel"].tap()
        tapFirstButton(app, identifier: "scheduled-lock-edit-button")
        XCTAssertEqual(app.switches["recurring-rule-enabled-toggle"].value as? String, "0")
        app.buttons["Cancel"].tap()
    }

    func testActiveRecurringCanBeDeletedWithConfirmation() throws {
        let app = launchApprovedSeededApp(extraArguments: ["--ui-testing-active-recurring", "--ui-testing-all-day-recurring"])
        XCTAssertTrue(app.staticTexts["Bear is sleeping."].waitForExistence(timeout: 10))
        scrollToStaticText("Repeats", in: app)
        let edit = app.buttons.matching(identifier: "scheduled-lock-edit-button").firstMatch
        let delete = app.buttons.matching(identifier: "scheduled-lock-delete-button").firstMatch
        XCTAssertTrue(edit.exists)
        XCTAssertTrue(delete.exists)
        XCTAssertFalse(edit.isEnabled)
        XCTAssertTrue(delete.isEnabled)
        XCTAssertTrue(app.staticTexts["Active. You can delete this schedule to end its lock."].exists)
        captureScreenshot(named: "e2e-active-recurring-deletable")
        delete.tap()
        XCTAssertTrue(app.staticTexts["Deleting this schedule also ends its active lock. Other schedules will keep blocking their targets."].waitForExistence(timeout: 5))
        captureScreenshot(named: "e2e-active-recurring-delete-confirmation")
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No scheduled locks."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Bear is sleeping."].exists)
        captureScreenshot(named: "e2e-active-recurring-deleted")
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-testing-approved"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No scheduled locks."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Bear is sleeping."].exists)
    }

    private func launchApprovedSeededApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-approved",
            "--ui-testing-seeded",
            "--ui-testing-target-summary",
            "--reset-ui-testing-state"
        ] + extraArguments
        app.launch()
        return app
    }

    private func scrollToButton(_ button: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !button.isHittable { app.swipeDown() }
        for _ in 0..<5 where !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable)
    }

    private func openNavigationLink(_ button: XCUIElement, destinationTitle: String, in app: XCUIApplication) {
        dismissErrorAlertIfPresent(in: app)
        scrollToButton(button, in: app)
        button.tap()

        let destination = app.navigationBars[destinationTitle]
        if !destination.waitForExistence(timeout: 3), button.exists {
            dismissErrorAlertIfPresent(in: app)
            scrollToButton(button, in: app)
            button.tap()
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 7), app.debugDescription)
    }

    private func dismissErrorAlertIfPresent(in app: XCUIApplication) {
        let alert = app.alerts["Bear Lock"]
        if alert.waitForExistence(timeout: 1) {
            alert.buttons["OK"].tap()
        }
    }

    private func tapFirstButton(_ app: XCUIApplication, identifier: String) {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        if !button.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Expected button with identifier \(identifier)")
        scrollToButton(button, in: app)
        button.tap()
    }

    private func waitForLabel(_ element: XCUIElement, toEqual label: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapSwitch(_ app: XCUIApplication, identifier: String, label: String) {
        let identifiedSwitch = app.switches.matching(identifier: identifier).firstMatch
        if identifiedSwitch.waitForExistence(timeout: 3) {
            let before = identifiedSwitch.value as? String
            identifiedSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let changed = NSPredicate(format: "value != %@", before ?? "")
            XCTAssertTrue(expectation(for: changed, evaluatedWith: identifiedSwitch).expectedFulfillmentCount == 1)
            waitForExpectations(timeout: 5)
            return
        }

        let labeledSwitch = app.switches[label]
        XCTAssertTrue(labeledSwitch.waitForExistence(timeout: 5), "Expected switch with identifier \(identifier) or label \(label)")
        labeledSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
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
