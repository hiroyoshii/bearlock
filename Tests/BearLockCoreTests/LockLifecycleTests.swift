import XCTest
@testable import BearLockCore

final class LockLifecycleTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_030)

    func testSecondPrecisionSurvivesScheduleConversion() throws {
        let rule = makeRule()
        let components = rule.monitoringComponents(calendar: utcCalendar)
        XCTAssertEqual(utcCalendar.date(from: components.end), rule.endsAt)
        XCTAssertEqual(components.end.second, 30)
    }

    func testFractionalDeadlineRoundsUpAndUsesSameScheduledEnd() throws {
        let request = LockCreationRequest.now(duration: 1800, targetSelectionID: UUID())
        let rule = try LockPlanner().makeRule(from: request, now: start.addingTimeInterval(0.25), existingRules: [], activeLock: nil)
        let active = LockPlanner().activeLock(from: rule)
        XCTAssertGreaterThanOrEqual(active.endsAt, start.addingTimeInterval(1800.25))
        XCTAssertEqual(utcCalendar.date(from: rule.monitoringComponents(calendar: utcCalendar).end), active.endsAt)
        XCTAssertEqual(active.scheduledEndsAt, active.endsAt)
    }

    func testLateStartKeepsOriginalDeadline() throws {
        let rule = makeRule()
        let harness = Harness(state: LockState(rules: [rule]))
        try harness.run(.intervalStarted(ruleID: rule.id), at: start.addingTimeInterval(300))
        XCTAssertEqual(harness.repository.state.activeLock?.endsAt, rule.endsAt)
        XCTAssertEqual(harness.applied.count, 1)
    }

    func testStartDeliveredAfterExpiryDoesNotRelock() throws {
        let rule = makeRule()
        let harness = Harness(state: LockState(rules: [rule]))
        try harness.run(.intervalStarted(ruleID: rule.id), at: rule.endsAt.addingTimeInterval(3600))
        XCTAssertTrue(harness.applied.isEmpty)
        XCTAssertEqual(harness.clears, 1)
        XCTAssertNil(harness.repository.state.activeLock)
    }

    func testDuplicateStartDoesNotReplaceActiveSnapshot() throws {
        let rule = makeRule()
        let active = LockPlanner().activeLock(from: rule)
        let harness = Harness(state: LockState(rules: [rule], activeLock: active))
        try harness.run(.intervalStarted(ruleID: rule.id), at: start.addingTimeInterval(600))
        XCTAssertEqual(harness.repository.state.activeLock, active)
        XCTAssertEqual(harness.applied, [active])
    }

    func testEarlyEndFromStopMonitoringDoesNotUnlock() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt.addingTimeInterval(-1))
        XCTAssertEqual(harness.clears, 0)
        XCTAssertNotNil(harness.repository.state.activeLock)
        XCTAssertTrue(harness.records.contains("keep=unexpiredOccurrence"))
    }

    func testEndAtDeadlineUnlocksBeforeHistorySave() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        harness.repository.onSave = { XCTAssertEqual(harness.clears, 1) }
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        XCTAssertNil(harness.repository.state.activeLock)
        XCTAssertEqual(harness.repository.state.completedLocks.count, 1)
    }

    func testHoursLateEndStillUnlocks() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt.addingTimeInterval(8 * 3600))
        XCTAssertEqual(harness.clears, 1)
    }

    func testSaveFailureDoesNotPreventUnlockAndRetryDoesNotDuplicateHistory() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        harness.repository.failSave = true
        XCTAssertThrowsError(try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt))
        XCTAssertEqual(harness.clears, 1)
        XCTAssertNotNil(harness.repository.state.activeLock)
        harness.repository.failSave = false
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        XCTAssertEqual(harness.repository.state.completedLocks.count, 1)
        XCTAssertEqual(harness.clears, 3)
    }

    func testCompletedStateWithResidualShieldIsClearedAgain() throws {
        let rule = makeRule()
        let completed = LockPlanner().activeLock(from: rule)
        let harness = Harness(state: LockState(rules: [rule], completedLocks: [completed]))
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        XCTAssertEqual(harness.clears, 1)
        XCTAssertTrue(harness.applied.isEmpty)
    }

    func testMissingActiveStateCanRecoverUsingExpiredRule() throws {
        let rule = makeRule()
        let harness = Harness(state: LockState(rules: [rule]))
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        XCTAssertEqual(harness.clears, 1)
    }

    func testMissingAllStateDoesNotTreatUnknownCallbackAsPermissionToClear() throws {
        let harness = Harness(state: LockState())
        try harness.run(.intervalEnded(ruleID: UUID()), at: start)
        XCTAssertEqual(harness.clears, 0)
    }

    func testReadFailureDoesNotClearOrSaveAndCanRecoverLater() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        harness.repository.failLoad = true
        XCTAssertThrowsError(try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt))
        XCTAssertEqual(harness.clears, 0)
        XCTAssertEqual(harness.repository.saves, 0)
        harness.repository.failLoad = false
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        XCTAssertEqual(harness.clears, 1)
    }

    func testUnrelatedEndDoesNotClearCurrentLockEvenIfExpired() throws {
        let rule = makeRule()
        let other = makeRule()
        let harness = activeHarness(rule, otherRules: [other])
        try harness.run(.intervalEnded(ruleID: other.id), at: rule.endsAt)
        XCTAssertEqual(harness.clears, 0)
        XCTAssertNotNil(harness.repository.state.activeLock)
        XCTAssertTrue(harness.records.contains("skip=activityMismatch"))
    }

    func testAppRefreshCanUnlockWithoutEndCallback() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        try harness.run(.refresh, at: rule.endsAt)
        XCTAssertEqual(harness.clears, 1)
    }

    func testLegacyOneShotDeadlineShiftIsRepaired() throws {
        let rule = makeRule()
        let active = ActiveLock(sourceRuleID: rule.id, startedAt: start.addingTimeInterval(300),
                                endsAt: rule.endsAt.addingTimeInterval(300), targetSelectionID: rule.targetSelectionID)
        let harness = Harness(state: LockState(rules: [rule], activeLock: active))
        try harness.run(.intervalEnded(ruleID: rule.id), at: rule.endsAt)
        XCTAssertEqual(harness.clears, 1)
        XCTAssertNil(harness.repository.state.activeLock)
    }

    func testOldEndDoesNotClearNextDueRuleWhenStartCallbackHasNotArrived() throws {
        let first = makeRule()
        let second = LockRule(kind: .fixedDateTime, startsAt: first.endsAt, duration: 1800, targetSelectionID: UUID())
        let harness = activeHarness(first, otherRules: [second])
        try harness.run(.intervalEnded(ruleID: first.id), at: first.endsAt)
        XCTAssertEqual(harness.clears, 0)
        XCTAssertEqual(harness.applied.first?.sourceRuleID, second.id)
        XCTAssertEqual(harness.repository.state.activeLock?.sourceRuleID, second.id)
    }

    func testRecurringOccurrenceAfterMidnightUsesPreviousDaysStart() throws {
        let rule = recurringRule()
        let now = date("2026-09-08T06:00:00Z")
        let harness = Harness(state: LockState(rules: [rule]))
        try harness.run(.intervalStarted(ruleID: rule.id), at: now)
        XCTAssertEqual(harness.applied.first?.startedAt, date("2026-09-07T23:00:00Z"))
        XCTAssertEqual(harness.applied.first?.endsAt, date("2026-09-08T07:00:00Z"))
    }

    func testOldRecurringEndDoesNotClearNewOccurrenceOfSameRule() throws {
        let rule = recurringRule()
        let occurrence = try XCTUnwrap(rule.occurrence(containing: date("2026-09-14T23:30:00Z")))
        let active = LockPlanner().activeLock(from: occurrence)
        let harness = Harness(state: LockState(rules: [rule], activeLock: active))
        try harness.run(.intervalEnded(ruleID: rule.id), at: date("2026-09-14T23:30:00Z"))
        XCTAssertEqual(harness.clears, 0)
        XCTAssertEqual(harness.repository.state.activeLock, active)
    }

    func testRecurringParentEditDoesNotShortenActiveOccurrence() throws {
        let original = recurringRule()
        let active = LockPlanner().activeLock(from: original)
        var edited = original
        edited.duration = 60
        edited.status = .disabled
        let harness = Harness(state: LockState(rules: [edited], activeLock: active))
        try harness.run(.intervalEnded(ruleID: original.id), at: original.startsAt.addingTimeInterval(120))
        XCTAssertEqual(harness.clears, 0)
        try harness.run(.intervalEnded(ruleID: original.id), at: active.endsAt)
        XCTAssertEqual(harness.clears, 1)
    }

    func testNewOccurrenceIsNotShieldedIfItsPersistenceFails() throws {
        let rule = makeRule()
        let harness = Harness(state: LockState(rules: [rule]))
        harness.repository.failSave = true
        XCTAssertThrowsError(try harness.run(.intervalStarted(ruleID: rule.id), at: start))
        XCTAssertTrue(harness.applied.isEmpty)
    }

    func testFailedStoreMutationCannotLeakIntoLaterSuccessfulSave() async throws {
        let repository = FaultRepository(state: LockState())
        let store = try LockStore(repository: repository)
        repository.failSave = true
        do {
            try await store.activate(LockPlanner().activeLock(from: makeRule()))
            XCTFail("Expected save failure")
        } catch { }
        repository.failSave = false
        _ = try await store.saveTargetSelection(LockTargetSelectionRef())
        XCTAssertNil(repository.state.activeLock)
        XCTAssertEqual(repository.state.targetSelections.count, 1)
    }

    func testCompletionCallbackMatchesExactSnapshotEvenForSameRule() throws {
        let rule = makeRule()
        let harness = activeHarness(rule)
        try harness.run(.intervalEnded(ruleID: rule.id, activeID: UUID()), at: rule.endsAt)
        XCTAssertEqual(harness.clears, 0)
        XCTAssertNotNil(harness.repository.state.activeLock)
    }

    func testCompletionMonitorRetainsImmutableDeadline() throws {
        let rule = makeRule()
        var active = LockPlanner().activeLock(from: rule)
        active.endsAt = rule.endsAt.addingTimeInterval(300)
        let preserved = active.completionMonitoringRule
        XCTAssertEqual(preserved.endsAt, rule.endsAt)
        XCTAssertEqual(utcCalendar.date(from: preserved.monitoringComponents(calendar: utcCalendar).end), rule.endsAt)
        XCTAssertFalse(preserved.kind == .recurring)
    }

    func testNextOccurrenceSaveFailureDoesNotLeaveExpiredPredecessorShield() throws {
        let first = makeRule()
        let next = LockRule(kind: .fixedDateTime, startsAt: first.endsAt, duration: 1800, targetSelectionID: UUID())
        let harness = activeHarness(first, otherRules: [next])
        harness.repository.failSave = true
        XCTAssertThrowsError(try harness.run(.intervalEnded(ruleID: first.id), at: first.endsAt))
        XCTAssertEqual(harness.clears, 1)
        XCTAssertTrue(harness.applied.isEmpty)
        harness.repository.failSave = false
        try harness.run(.refresh, at: first.endsAt)
        XCTAssertEqual(harness.repository.state.activeLock?.sourceRuleID, next.id)
    }

    private func makeRule() -> LockRule {
        LockRule(kind: .immediate, startsAt: start, duration: 1800, targetSelectionID: UUID())
    }

    private func activeHarness(_ rule: LockRule, otherRules: [LockRule] = []) -> Harness {
        Harness(state: LockState(rules: [rule] + otherRules, activeLock: LockPlanner().activeLock(from: rule)))
    }

    private func recurringRule() -> LockRule {
        LockRule(kind: .recurring, startsAt: date("2026-09-07T23:00:00Z"), duration: 8 * 3600,
                 recurrence: RecurrenceRule(weekdays: [.monday], startsAt: TimeOfDay(hour: 23, minute: 0),
                                            endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC"),
                 targetSelectionID: UUID())
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private final class Harness {
    let repository: FaultRepository
    var clears = 0
    var applied: [ActiveLock] = []
    var records: [String] = []
    init(state: LockState) { repository = FaultRepository(state: state) }
    func run(_ event: LockLifecycleEvent, at now: Date) throws {
        try LockLifecycle(repository: repository).reconcile(
            event: event, at: now,
            apply: { active, _ in self.applied.append(active) },
            clear: { self.clears += 1 }, record: { self.records.append($0) }
        )
    }
}

private final class FaultRepository: LockRepository, @unchecked Sendable {
    enum Failure: Error { case injected }
    var state: LockState
    var failSave = false
    var failLoad = false
    var saves = 0
    var onSave: (() -> Void)?
    init(state: LockState) { self.state = state }
    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T { try body() }
    func load() throws -> LockState {
        if failLoad { throw Failure.injected }
        return state
    }
    func save(_ state: LockState) throws {
        onSave?()
        if failSave { throw Failure.injected }
        saves += 1
        self.state = state
    }
}
