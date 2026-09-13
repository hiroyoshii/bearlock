import BearLockCore
import XCTest

@MainActor
final class BearLockAppModelTests: XCTestCase {
    func testMonitoringFailureKeepsSavedRuleAndRefreshRetriesWithoutCreatingAnother() async throws {
        let h = try Harness()
        await h.model.refresh()
        h.schedule.fail = true
        let saved = await h.model.createLock(.now(duration: 300, targetSelectionID: h.target.id))
        XCTAssertTrue(saved)
        XCTAssertEqual(h.model.lockState.rules.count, 1)
        XCTAssertNotNil(h.model.lastErrorMessage)
        XCTAssertNotNil(h.model.activeLock)
        let rule = try XCTUnwrap(h.model.lockState.rules.first)
        h.schedule.fail = false
        await h.model.refresh()
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

    func testActiveRecurringEditDisableAndDeleteLeaveRuleAndMonitoringUnchanged() async throws {
        let h = try Harness()
        let now = Date(), calendar = Calendar.current
        let start = now.addingTimeInterval(-60), end = now.addingTimeInterval(180)
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases),
            startsAt: TimeOfDay(hour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start)),
            endsAt: TimeOfDay(hour: calendar.component(.hour, from: end), minute: calendar.component(.minute, from: end)))
        let rule = LockRule(kind: .recurring, startsAt: start, duration: recurrence.duration,
            recurrence: recurrence, targetSelectionID: h.target.id)
        h.repository.state.rules = [rule]
        await h.model.refresh()
        let calls = h.schedule.calls
        let saved = await h.model.updateRecurringRule(rule, recurrence: recurrence, enabled: false)
        XCTAssertFalse(saved)
        await h.model.deleteScheduledRule(rule)
        XCTAssertEqual(h.model.lockState.rules, [rule])
        XCTAssertEqual(h.schedule.calls, calls)
        XCTAssertEqual(h.shield.selections, [h.target])
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
        model = BearLockAppModel(authorizationService: PreviewAuthorizationService(status: .approved),
            targetSelectionStore: PreviewTargetSelectionStore(), shieldController: shield,
            scheduleController: schedule, lockStore: try LockStore(repository: repository))
    }
}
private enum TestFailure: Error { case unavailable }
private final class TestScheduleController: ScheduleControlling, @unchecked Sendable {
    var fail = false
    var rules: [LockRule] = []
    var calls = 0
    func synchronize(_ rules: [LockRule], at now: Date) throws {
        calls += 1
        if fail { throw TestFailure.unavailable }
        self.rules = rules
    }
}
private final class TestShieldController: ShieldControlling, @unchecked Sendable {
    var selections: [LockTargetSelectionRef]?
    func applyShield(selections: [LockTargetSelectionRef]) throws { self.selections = selections }
}
private final class MemoryRepository: LockRepository, @unchecked Sendable {
    var state = LockState()
    var failWrite = false
    private let lock = NSRecursiveLock()
    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }; return try body()
    }
    func load() throws -> LockState { try withExclusiveAccess { state } }
    func save(_ state: LockState) throws {
        try withExclusiveAccess {
            if failWrite { throw TestFailure.unavailable }
            self.state = state
        }
    }
}
