import BearLockCore
import FamilyControls
import XCTest

@MainActor
final class BearLockAppModelTests: XCTestCase {
    func testHistoryChangesNeverReflectAndPreserveLocksSelectionAndMonitoringFailure() async throws {
        let h = try Harness()
        let recent = RecentLockTarget(targetSelectionID: h.target.id, lastUsedAt: Date())
        let now = Date(), start = now.addingTimeInterval(-60)
        let rule = LockRule(kind: .immediate, startsAt: start, duration: 7200, targetSelectionID: h.target.id)
        h.repository.state.recentLockTargets = [recent]
        h.repository.state.rules = [rule]
        h.repository.state.wakeState = WakeState(requests: [WakeRequest(ruleID: rule.id, occurrenceStartedAt: start,
            requestedAt: now, wakesAt: now.addingTimeInterval(1800), source: .delayed)])
        h.schedule.fail = true
        await h.model.refresh()
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        let original = h.repository.state, calls = h.schedule.calls, shieldCalls = h.shield.calls
        h.shield.fail = true
        let pinned = await h.model.setRecentLockTargetPinned(recent, pinned: true)
        XCTAssertEqual(pinned, .saved)
        XCTAssertTrue(try XCTUnwrap(h.model.lockState.recentLockTargets.first).isPinned)
        let unpinned = await h.model.setRecentLockTargetPinned(recent, pinned: false)
        XCTAssertEqual(unpinned, .saved)
        XCTAssertFalse(try XCTUnwrap(h.model.lockState.recentLockTargets.first).isPinned)
        let deleted = await h.model.deleteRecentLockTarget(recent)
        XCTAssertEqual(deleted, .saved)
        XCTAssertTrue(h.model.lockState.recentLockTargets.isEmpty)
        XCTAssertEqual(h.repository.state.rules, original.rules)
        XCTAssertEqual(h.repository.state.wakeState, original.wakeState)
        XCTAssertEqual(h.repository.state.targetSelections, original.targetSelections)
        XCTAssertEqual(h.repository.state.selectedTargetID, original.selectedTargetID)
        XCTAssertEqual(h.schedule.calls, calls)
        XCTAssertEqual(h.shield.calls, shieldCalls)
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        XCTAssertNil(h.model.lastErrorMessage)
    }

    func testHistoryReadAndWriteFailuresRejectWithoutReflectionOrMutation() async throws {
        for readFailure in [false, true] {
            for action in ["pin", "unpin", "delete"] {
                let h = try Harness()
                let recent = RecentLockTarget(targetSelectionID: h.target.id, lastUsedAt: Date(),
                    pinnedAt: action == "unpin" ? Date() : nil)
                h.repository.state.recentLockTargets = [recent]
                await h.model.refresh()
                let original = h.repository.state, calls = h.schedule.calls, shieldCalls = h.shield.calls
                h.repository.failRead = readFailure
                h.repository.failWrite = !readFailure
                let outcome: OperationOutcome
                if action == "delete" { outcome = await h.model.deleteRecentLockTarget(recent) }
                else { outcome = await h.model.setRecentLockTargetPinned(recent, pinned: action == "pin") }
                XCTAssertEqual(outcome, .rejected)
                XCTAssertEqual(h.repository.state, original)
                XCTAssertEqual(h.model.lockState, original)
                XCTAssertEqual(h.schedule.calls, calls)
                XCTAssertEqual(h.shield.calls, shieldCalls)
                XCTAssertFalse(h.model.isUpdatingLock)
            }
        }
    }

    func testHistoryPostCommitReloadFailureIsSavedAndRecoveryDoesNotReplay() async throws {
        for action in ["pin", "unpin", "delete"] {
            let h = try Harness()
            let recent = RecentLockTarget(targetSelectionID: h.target.id, lastUsedAt: Date(),
                pinnedAt: action == "unpin" ? Date() : nil)
            h.repository.state.recentLockTargets = [recent]
            await h.model.refresh()
            let original = h.model.lockState, calls = h.schedule.calls, shieldCalls = h.shield.calls
            h.repository.failReadAfterWrite = true
            let outcome: OperationOutcome
            if action == "delete" { outcome = await h.model.deleteRecentLockTarget(recent) }
            else { outcome = await h.model.setRecentLockTargetPinned(recent, pinned: action == "pin") }
            XCTAssertEqual(outcome, .savedNeedsReload)
            XCTAssertTrue(outcome.isSaved)
            XCTAssertEqual(h.model.readStatus, .failed)
            XCTAssertEqual(h.model.lockState, original)
            XCTAssertNil(h.model.lastErrorMessage)
            XCTAssertEqual(h.schedule.calls, calls)
            XCTAssertEqual(h.shield.calls, shieldCalls)
            let committed = h.repository.state, writes = h.repository.writes
            XCTAssertNotEqual(committed, original)
            h.repository.failRead = false
            h.repository.failReadAfterWrite = false
            // Normal storage recovery reloads/reconciles all state, but never replays the history command.
            await h.model.refresh()
            XCTAssertEqual(h.model.readStatus, .loaded)
            XCTAssertEqual(h.model.lockState, committed)
            XCTAssertEqual(h.repository.writes, writes)
            XCTAssertFalse(h.model.isUpdatingLock)
        }
    }

    func testHistoryPinLimitIsRevalidatedAgainstLatestSavedHistory() async throws {
        let h = try Harness()
        let recent = RecentLockTarget(targetSelectionID: h.target.id, lastUsedAt: Date())
        h.repository.state.recentLockTargets = [recent]
        await h.model.refresh()
        for index in 1...3 {
            let target = LockTargetSelectionRef(displayName: "Pinned \(index)")
            h.repository.state.targetSelections.append(target)
            h.repository.state.recentLockTargets.append(RecentLockTarget(targetSelectionID: target.id,
                lastUsedAt: Date(), pinnedAt: Date()))
        }
        let original = h.repository.state, calls = h.schedule.calls, shieldCalls = h.shield.calls
        let outcome = await h.model.setRecentLockTargetPinned(recent, pinned: true)
        XCTAssertEqual(outcome, .rejected)
        XCTAssertEqual(h.repository.state, original)
        XCTAssertEqual(h.schedule.calls, calls)
        XCTAssertEqual(h.shield.calls, shieldCalls)
    }

    func testCreatedRuleSurvivesPostCommitReloadFailureWithoutReplay() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.repository.failReadAfterWrite = true
        let outcome = await h.model.createLock(.delayed(delay: 3600, duration: 300, targetSelectionID: h.target.id))
        XCTAssertEqual(outcome, .savedNeedsReflection)
        XCTAssertEqual(h.model.readStatus, .failed)
        XCTAssertEqual(h.repository.state.rules.count, 1)
        XCTAssertFalse(h.model.isCreatingLock)
        XCTAssertFalse(h.model.isUpdatingLock)
        let saved = h.repository.state, writes = h.repository.writes
        h.repository.failRead = false
        h.repository.failReadAfterWrite = false
        await h.model.refresh()
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testHistoryFailureDoesNotRejectCommittedRuleOrReplayCreation() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.repository.failWriteAt = h.repository.writes + 2 // Keep existing separate history-save semantics.
        let outcome = await h.model.createLock(.delayed(delay: 3600, duration: 300, targetSelectionID: h.target.id))
        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(h.repository.state.rules.count, 1)
        XCTAssertTrue(h.repository.state.recentLockTargets.isEmpty)
        XCTAssertNil(h.model.lastErrorMessage)
        let saved = h.repository.state, writes = h.repository.writes
        h.repository.failWriteAt = nil
        await h.model.refresh()
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testScheduledEditDistinguishesFailedSaveFromFailedReflection() async throws {
        let h = try Harness()
        let start = Date(timeIntervalSince1970: ceil(Date().timeIntervalSince1970) + 7200)
        let rule = LockRule(kind: .fixedDateTime, startsAt: start, duration: 300, targetSelectionID: h.target.id)
        h.repository.state.rules = [rule]
        await h.model.refresh()
        let original = h.repository.state, calls = h.schedule.calls
        h.repository.failWrite = true
        let failed = await h.model.updateScheduledRule(rule, startsAt: start.addingTimeInterval(600), duration: 300)
        XCTAssertEqual(failed, .rejected)
        XCTAssertEqual(h.repository.state, original)
        XCTAssertEqual(h.schedule.calls, calls)
        h.repository.failWrite = false
        h.model.lastErrorMessage = nil
        h.schedule.fail = true
        let updated = await h.model.updateScheduledRule(rule, startsAt: start.addingTimeInterval(600), duration: 300)
        XCTAssertEqual(updated, .savedNeedsReflection)
        XCTAssertEqual(h.repository.state.rules.first?.single?.startsAt, start.addingTimeInterval(600))
        XCTAssertNil(h.model.lastErrorMessage)
        let saved = h.repository.state, writes = h.repository.writes
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testStaleEditorRevalidatesStartedAndDeletedRules() async throws {
        let h = try Harness()
        let start = Date().addingTimeInterval(3600)
        let displayed = LockRule(kind: .fixedDateTime, startsAt: start, duration: 300, targetSelectionID: h.target.id)
        h.repository.state.rules = [displayed]
        await h.model.refresh()
        let started = LockRule(id: displayed.id, kind: .fixedDateTime,
            startsAt: Date().addingTimeInterval(-60), duration: 300, targetSelectionID: h.target.id)
        h.repository.state.rules = [started]
        let original = h.repository.state, calls = h.schedule.calls
        let edit = await h.model.updateScheduledRule(displayed, startsAt: start, duration: 300)
        let delete = await h.model.deleteScheduledRule(displayed)
        XCTAssertEqual(edit, .rejected)
        XCTAssertEqual(delete, .rejected)
        XCTAssertEqual(h.repository.state, original)
        XCTAssertEqual(h.schedule.calls, calls)
        h.repository.state.rules = []
        let missing = await h.model.updateScheduledRule(displayed, startsAt: start, duration: 300)
        XCTAssertEqual(missing, .rejected)
        XCTAssertTrue(h.repository.state.rules.isEmpty)
    }

    func testDeletionSurvivesPostCommitReloadFailureAndRetryDoesNotResave() async throws {
        let h = try Harness()
        let rule = LockRule(kind: .fixedDateTime, startsAt: Date().addingTimeInterval(3600), duration: 300, targetSelectionID: h.target.id)
        h.repository.state.rules = [rule]
        await h.model.refresh()
        h.repository.failReadAfterWrite = true
        let outcome = await h.model.deleteScheduledRule(rule)
        XCTAssertEqual(outcome, .savedNeedsReflection)
        XCTAssertTrue(h.repository.state.rules.isEmpty)
        let writes = h.repository.writes
        h.repository.failRead = false
        h.repository.failReadAfterWrite = false
        await h.model.refresh()
        XCTAssertTrue(h.model.lockState.rules.isEmpty)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testRecurringEditAndDeletionCancellationUseCommitOutcome() async throws {
        let h = try Harness()
        let now = Date(), calendar = Calendar.current
        let start = now.addingTimeInterval(-60), end = now.addingTimeInterval(180)
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases),
            startsAt: TimeOfDay(hour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start)),
            endsAt: TimeOfDay(hour: calendar.component(.hour, from: end), minute: calendar.component(.minute, from: end)))
        let rule = LockRule(recurrence: recurrence, targetSelectionID: h.target.id, status: .disabled)
        h.repository.state.rules = [rule]
        await h.model.refresh()
        let enabled = await h.model.updateRecurringRule(rule, recurrence: recurrence, enabled: true)
        XCTAssertEqual(enabled, .saved)
        let deleted = await h.model.deleteScheduledRule(rule)
        XCTAssertEqual(deleted, .saved)
        XCTAssertNotNil(h.repository.state.rules.first?.scheduledDeletionAt)
        let pending = h.repository.state
        h.repository.failWrite = true
        let failedCancel = await h.model.cancelScheduledDeletion(rule)
        XCTAssertEqual(failedCancel, .rejected)
        XCTAssertEqual(h.repository.state, pending)
        h.repository.failWrite = false
        h.model.lastErrorMessage = nil
        h.schedule.fail = true
        let cancelled = await h.model.cancelScheduledDeletion(rule)
        XCTAssertEqual(cancelled, .savedNeedsReflection)
        XCTAssertNil(h.repository.state.rules.first?.scheduledDeletionAt)
        XCTAssertNotNil(h.model.activeLock)
        let saved = h.repository.state, writes = h.repository.writes
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testPostCommitReadFailureIsNotReportedAsARejectedSelection() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.repository.failReadAfterWrite = true
        let outcome = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertEqual(outcome, .savedNeedsReflection)
        XCTAssertEqual(h.model.readStatus, .failed)
        XCTAssertEqual(h.repository.state.selectedTarget?.displayName, "UI test targets")
        let writes = h.repository.writes
        h.repository.failRead = false
        h.repository.failReadAfterWrite = false
        await h.model.refresh()
        XCTAssertEqual(h.model.lockState, h.repository.state)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testPostCommitShieldFailureKeepsSelectionAndOffersReflectionRetry() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.shield.fail = true
        let outcome = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertEqual(outcome, .savedNeedsReflection)
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        XCTAssertNil(h.model.lastErrorMessage)
        let saved = h.repository.state
        h.shield.fail = false
        await h.model.refresh()
        XCTAssertFalse(h.model.monitoringUpdateFailed)
        XCTAssertEqual(h.repository.state, saved)
    }

    func testSelectionReflectionFailureIsSavedAndRetryDoesNotSaveAgain() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.schedule.fail = true
        let outcome = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertEqual(outcome, .savedNeedsReflection)
        XCTAssertTrue(outcome.isSaved)
        let saved = h.repository.state
        let writes = h.repository.writes
        XCTAssertEqual(h.model.lockState, saved)
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        XCTAssertNil(h.model.lastErrorMessage)
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertFalse(h.model.monitoringUpdateFailed)
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
    }

    func testFreeWakeFailureReflectionAndCancellationUseTheSameCommitBoundary() async throws {
        let h = try Harness()
        h.repository.state.rules = [LockRule(kind: .immediate, startsAt: Date().addingTimeInterval(-60),
            duration: 7200, targetSelectionID: h.target.id)]
        await h.model.refresh()
        let lock = try XCTUnwrap(h.model.activeLock)
        let original = h.repository.state
        let calls = h.schedule.calls
        h.repository.failWrite = true
        let rejected = await h.model.scheduleFreeWake(for: lock)
        XCTAssertEqual(rejected, .rejected)
        XCTAssertEqual(h.repository.state, original)
        XCTAssertEqual(h.schedule.calls, calls)
        h.repository.failWrite = false
        h.model.lastErrorMessage = nil
        h.schedule.fail = true
        let scheduled = await h.model.scheduleFreeWake(for: lock)
        XCTAssertEqual(scheduled, .savedNeedsReflection)
        let saved = h.repository.state
        let writes = h.repository.writes
        XCTAssertEqual(saved.wakeState.requests.count, 1)
        XCTAssertNil(h.model.lastErrorMessage)
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
        h.repository.failWrite = true
        let failedCancel = await h.model.cancelFreeWake(for: lock)
        XCTAssertEqual(failedCancel, .rejected)
        XCTAssertEqual(h.repository.state, saved)
        h.repository.failWrite = false
        h.schedule.fail = true
        let cancelled = await h.model.cancelFreeWake(for: lock)
        XCTAssertEqual(cancelled, .savedNeedsReflection)
        XCTAssertTrue(h.repository.state.wakeState.requests.isEmpty)
        XCTAssertEqual(h.repository.state.rules, original.rules)
    }

    func testConflictingWakeCancellationKeepsBookingAndDoesNotReflect() async throws {
        let h = try Harness()
        let now = Date()
        let first = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60),
            duration: 7200, targetSelectionID: h.target.id)
        let wake = WakeRequest(ruleID: first.id, occurrenceStartedAt: first.single!.startsAt,
            requestedAt: now, wakesAt: now.addingTimeInterval(1800), source: .delayed)
        let next = LockRule(kind: .fixedDateTime, startsAt: wake.wakesAt, duration: 900,
            targetSelectionID: h.target.id)
        h.repository.state.rules = [first, next]
        h.repository.state.wakeState.requests = [wake]
        await h.model.refresh()
        let lock = try XCTUnwrap(h.model.activeLock)
        let saved = h.repository.state
        let writes = h.repository.writes
        let monitoring = h.schedule.calls
        let shields = h.shield.calls
        let outcome = await h.model.cancelFreeWake(for: lock)
        XCTAssertEqual(outcome, .rejected)
        XCTAssertNotNil(h.model.lastErrorMessage)
        XCTAssertEqual(h.repository.state, saved)
        XCTAssertEqual(h.repository.writes, writes)
        XCTAssertEqual(h.schedule.calls, monitoring)
        XCTAssertEqual(h.shield.calls, shields)
    }

    func testConfirmedWakeOccurrenceCannotTransferToNewRepresentative() async throws {
        let h = try Harness()
        let old = LockRule(kind: .immediate, startsAt: Date().addingTimeInterval(-60),
            duration: 7200, targetSelectionID: h.target.id)
        h.repository.state.rules = [old]
        await h.model.refresh()
        let confirmed = try XCTUnwrap(h.model.activeLock)
        let next = LockRule(kind: .immediate, startsAt: Date().addingTimeInterval(-30),
            duration: 10800, targetSelectionID: h.target.id)
        let ended = LockRule(id: old.id, kind: .immediate, startsAt: confirmed.startedAt,
            duration: 1, targetSelectionID: h.target.id)
        for rules in [[next], [ended, next]] {
            h.repository.state.rules = rules
            await h.model.refresh()
            XCTAssertEqual(h.model.activeLock?.id, next.id)
            let current = h.repository.state
            let result = await h.model.scheduleFreeWake(for: confirmed)
            XCTAssertEqual(result, .rejected)
            XCTAssertEqual(h.repository.state, current)
            let cancel = await h.model.cancelFreeWake(for: confirmed)
            XCTAssertEqual(cancel, .rejected)
            XCTAssertEqual(h.repository.state, current)
        }
    }

    func testSelectionRevalidatesAfterDisplayedStateHasBecomeStale() async throws {
        let h = try Harness()
        await h.model.refresh()
        XCTAssertNil(h.model.activeLock)
        h.repository.state.rules = [LockRule(kind: .immediate, startsAt: Date().addingTimeInterval(-1),
            duration: 3600, targetSelectionID: h.target.id)]
        let current = h.repository.state
        let result = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertEqual(result, .rejected)
        XCTAssertEqual(h.repository.state, current)
    }

    func testReuseChangesSelectionAndSummaryWithoutChangingTargetCatalog() async throws {
        let first = LockTargetSelectionRef(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, displayName: "3 targets")
        let second = LockTargetSelectionRef(id: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!, displayName: "2 targets")
        let recent = RecentLockTarget(targetSelectionID: second.id, lastUsedAt: Date())
        let repository = MemoryRepository()
        repository.state = LockState(targetSelections: [first, second], recentLockTargets: [recent])
        repository.state.selectedTargetID = first.id
        let codec = PreviewTargetSelectionCodec(usesSummaryFixtures: true)
        let model = BearLockAppModel(authorizationService: PreviewAuthorizationService(status: .approved),
            targetSelectionCodec: codec, shieldController: NoopShieldController(),
            scheduleController: NoopScheduleController(), lockStore: LockStore(repository: repository))
        await model.refresh()
        XCTAssertEqual(try codec.summary(from: model.lockState.selectedTarget).total, 3)
        await model.selectRecentLockTarget(recent)
        XCTAssertEqual(model.lockState.targetSelections, [first, second])
        XCTAssertEqual(model.lockState.selectedTarget, second)
        let summary = try codec.summary(from: model.lockState.selectedTarget)
        XCTAssertEqual(summary.total, 2)
        XCTAssertEqual(summary.previewApplicationNames, ["Books", "Music"])
        XCTAssertEqual(repository.state.selectedTargetID, second.id)
    }

    func testInitialReadFailureStaysFailedUntilRetryLoadsSavedData() async throws {
        let h = try Harness()
        let original = h.repository.state
        h.repository.failRead = true
        await h.model.refresh()
        XCTAssertEqual(h.model.readStatus, .failed)
        XCTAssertFalse(h.model.hasLoadedInitialState)
        XCTAssertNil(h.model.lastErrorMessage)
        XCTAssertEqual(h.schedule.calls, 0)
        await h.model.refresh()
        XCTAssertEqual(h.model.readStatus, .failed)
        XCTAssertEqual(h.repository.state, original)
        h.repository.failRead = false
        await h.model.refresh()
        XCTAssertEqual(h.model.readStatus, .loaded)
        XCTAssertTrue(h.model.hasLoadedInitialState)
        XCTAssertEqual(h.model.lockState, original)
    }

    func testLaterReadFailurePreservesLastSnapshotShieldAndMonitoringError() async throws {
        let h = try Harness()
        h.repository.state.rules = [LockRule(kind: .immediate, startsAt: Date().addingTimeInterval(-60),
            duration: 3600, targetSelectionID: h.target.id)]
        h.schedule.fail = true
        await h.model.refresh()
        let original = h.model.lockState
        let applied = h.shield.selections
        let calls = h.schedule.calls
        h.repository.failRead = true
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertEqual(h.model.readStatus, .failed)
        XCTAssertEqual(h.model.lockState, original)
        XCTAssertEqual(h.shield.selections, applied)
        XCTAssertEqual(h.schedule.calls, calls)
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        h.repository.failRead = false
        await h.model.refresh()
        XCTAssertEqual(h.model.readStatus, .loaded)
        XCTAssertFalse(h.model.monitoringUpdateFailed)
        XCTAssertEqual(h.model.lockState, original)
    }

    func testTargetSaveFailureKeepsCurrentSelectionAndRetryCommitsIt() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.repository.failWrite = true
        let failed = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertEqual(failed, .rejected)
        XCTAssertEqual(h.model.lockState.selectedTargetID, h.target.id)
        XCTAssertEqual(h.repository.state.targetSelections, [h.target])
        h.repository.failWrite = false
        let saved = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertEqual(saved, .saved)
        XCTAssertNotEqual(h.model.lockState.selectedTargetID, h.target.id)
        XCTAssertEqual(h.model.lockState, h.repository.state)
        XCTAssertEqual(h.repository.state.selectedTarget?.displayName, "UI test targets")
    }

    func testMonitoringFailureKeepsSavedRuleAndRefreshRetriesWithoutCreatingAnother() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.schedule.fail = true
        let saved = await h.model.createLock(.now(duration: 300, targetSelectionID: h.target.id))
        XCTAssertEqual(saved, .savedNeedsReflection)
        XCTAssertEqual(h.model.lockState.rules.count, 1)
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        XCTAssertNil(h.model.lastErrorMessage)
        XCTAssertNotNil(h.model.activeLock)
        let rule = try XCTUnwrap(h.model.lockState.rules.first)
        await h.model.refresh()
        XCTAssertTrue(h.model.monitoringUpdateFailed)
        XCTAssertEqual(h.model.lockState.rules, [rule])
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertFalse(h.model.monitoringUpdateFailed)
        XCTAssertEqual(h.schedule.rules, [rule])
        XCTAssertEqual(h.model.lockState.rules, [rule])
    }

    func testScheduleFailureCannotPreventClearingExpiredShield() async throws {
        let h = try Harness()
        h.repository.state.rules = [LockRule(kind: .immediate, startsAt: Date().addingTimeInterval(-3600),
            duration: 300, targetSelectionID: h.target.id)]
        h.schedule.fail = true
        await h.model.refresh()
        XCTAssertEqual(h.shield.selections, [])
        XCTAssertNil(h.model.activeLock)
    }

    func testSaveFailureLeavesEditorOpenAndDoesNotRegisterOrApplyNewLock() async throws {
        let h = try Harness()
        await h.model.refresh()
        let calls = h.schedule.calls
        h.repository.failWrite = true
        let saved = await h.model.createLock(.now(duration: 300, targetSelectionID: h.target.id))
        XCTAssertEqual(saved, .rejected)
        XCTAssertEqual(h.schedule.calls, calls)
        XCTAssertTrue(h.model.lockState.rules.isEmpty)
        XCTAssertEqual(h.shield.selections, [])
    }

    func testActiveRecurringDeletionFailureKeepsRuleAndRetrySchedulesDeletionDespiteMonitorFailure() async throws {
        let h = try Harness()
        let now = Date(), calendar = Calendar.current
        let start = now.addingTimeInterval(-60), end = now.addingTimeInterval(180)
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases),
            startsAt: TimeOfDay(hour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start)),
            endsAt: TimeOfDay(hour: calendar.component(.hour, from: end), minute: calendar.component(.minute, from: end)))
        let rule = LockRule(
            recurrence: recurrence, targetSelectionID: h.target.id)
        h.repository.state.rules = [rule]
        await h.model.refresh()
        let calls = h.schedule.calls
        let saved = await h.model.updateRecurringRule(rule, recurrence: recurrence, enabled: false)
        XCTAssertEqual(saved, .rejected)
        h.repository.failWrite = true
        await h.model.deleteScheduledRule(rule)
        XCTAssertEqual(h.model.lockState.rules, [rule])
        XCTAssertEqual(h.schedule.calls, calls)
        XCTAssertEqual(h.shield.selections, [h.target])
        h.repository.failWrite = false
        h.schedule.fail = true
        await h.model.deleteScheduledRule(rule)
        XCTAssertEqual(h.model.lockState.rules.count, 1)
        XCTAssertNotNil(h.model.lockState.rules.first?.scheduledDeletionAt)
        XCTAssertEqual(h.shield.selections, [h.target])
        XCTAssertNotNil(h.model.activeLock)
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertEqual(h.schedule.rules, h.model.lockState.rules)
    }

    func testFailedMonitorRemovalRetriesFromDeletedDesiredRule() async throws {
        let h = try Harness()
        await h.model.refresh()
        let saved = await h.model.createLock(.delayed(delay: 3600, duration: 300, targetSelectionID: h.target.id))
        XCTAssertEqual(saved, .saved)
        let rule = try XCTUnwrap(h.model.lockState.rules.first)
        h.schedule.fail = true
        await h.model.deleteScheduledRule(rule)
        XCTAssertTrue(h.model.lockState.rules.isEmpty)
        h.schedule.fail = false
        await h.model.refresh()
        XCTAssertEqual(h.schedule.rules, [])
    }
}

@MainActor
private final class Harness {
    let target = LockTargetSelectionRef(displayName: "Apps")
    let repository = MemoryRepository()
    let schedule = TestScheduleController()
    let shield = TestShieldController()
    let model: BearLockAppModel
    init() throws {
        repository.state.targetSelections = [target]
        repository.state.selectedTargetID = target.id
        model = BearLockAppModel(authorizationService: PreviewAuthorizationService(status: .approved),
            targetSelectionCodec: PreviewTargetSelectionCodec(), shieldController: shield,
            scheduleController: schedule, lockStore: LockStore(repository: repository))
    }
}
private enum TestFailure: Error { case unavailable }
private final class TestScheduleController: ScheduleControlling, @unchecked Sendable {
    var fail = false
    var rules: [LockRule] = []
    var calls = 0
    func synchronize(_ state: LockState, at now: Date) throws {
        calls += 1
        if fail { throw TestFailure.unavailable }
        self.rules = state.rules
    }
}
private final class TestShieldController: ShieldControlling, @unchecked Sendable {
    var selections: [LockTargetSelectionRef]?
    var fail = false
    var calls = 0
    func reconcile(state: LockState, at date: Date) throws {
        calls += 1
        if fail { throw TestFailure.unavailable }
        selections = try state.shieldSlotDecisions(at: date).map(\.selection)
    }
}
private final class MemoryRepository: LockRepository, @unchecked Sendable {
    var state = LockState()
    var failRead = false
    var failWrite = false
    var failWriteAt: Int?
    var failReadAfterWrite = false
    var writes = 0
    private let lock = NSRecursiveLock()
    private func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body()
    }
    func load() throws -> LockState {
        try synchronized {
            if failRead { throw TestFailure.unavailable }
            return state
        }
    }
    func save(_ state: LockState) throws {
        try synchronized {
            if failWrite || failWriteAt == writes + 1 { throw TestFailure.unavailable }
            self.state = state
            writes += 1
            if failReadAfterWrite { failRead = true }
        }
    }
}
