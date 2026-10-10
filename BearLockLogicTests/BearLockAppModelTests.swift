import BearLockCore
import FamilyControls
import XCTest

@MainActor
final class BearLockAppModelTests: XCTestCase {
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
        XCTAssertFalse(failed)
        XCTAssertEqual(h.model.lockState.selectedTargetID, h.target.id)
        XCTAssertEqual(h.repository.state.targetSelections, [h.target])
        h.repository.failWrite = false
        let saved = await h.model.saveSelection(FamilyActivitySelection())
        XCTAssertTrue(saved)
        XCTAssertNotEqual(h.model.lockState.selectedTargetID, h.target.id)
        XCTAssertEqual(h.model.lockState, h.repository.state)
        XCTAssertEqual(h.repository.state.selectedTarget?.displayName, "UI test targets")
    }

    func testMonitoringFailureKeepsSavedRuleAndRefreshRetriesWithoutCreatingAnother() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.schedule.fail = true
        let saved = await h.model.createLock(.now(duration: 300, targetSelectionID: h.target.id))
        XCTAssertTrue(saved)
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
        XCTAssertFalse(saved)
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
        XCTAssertFalse(saved)
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
        XCTAssertTrue(saved)
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
    func reconcile(state: LockState, at date: Date) throws {
        selections = try state.shieldSlotDecisions(at: date).map(\.selection)
    }
}
private final class MemoryRepository: LockRepository, @unchecked Sendable {
    var state = LockState()
    var failRead = false
    var failWrite = false
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
            if failWrite { throw TestFailure.unavailable }
            self.state = state
        }
    }
}
