import XCTest
@testable import BearLockCore

final class LockLifecycleTests: XCTestCase {
    private let target = LockTargetSelectionRef(displayName: "Apps")
    private let start = ISO8601DateFormatter().date(from: "2026-09-10T23:00:00Z")!

    func testLateOrDuplicateCallsNeverMoveTheDeadline() throws {
        let rule = oneShot()
        let repository = FaultRepository(LockState(targetSelections: [target], rules: [rule]))
        let lifecycle = LockLifecycle(repository: repository)
        for offset in [0.0, 100, 100, 3599] {
            let state = try lifecycle.reconcile(at: start.addingTimeInterval(offset), apply: {
                XCTAssertEqual($0, [self.target])
            })
            XCTAssertEqual(state.activeLocks(at: start.addingTimeInterval(offset)).first?.endsAt, rule.single!.endsAt)
        }
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testDeadlineAndHoursLateCallsClearEvenWithoutAnyPreviousCall() throws {
        for offset in [3600.0, 3601, 86400] {
            let repository = FaultRepository(LockState(targetSelections: [target], rules: [oneShot()]))
            var applied: [LockTargetSelectionRef]?
            try LockLifecycle(repository: repository).reconcile(at: start.addingTimeInterval(offset), apply: { applied = $0 })
            XCTAssertEqual(applied, [])
            XCTAssertEqual(repository.saveCount, 0)
        }
    }

    func testEarlyEndAndUnrelatedCallbackCannotClearCurrentRule() throws {
        // Callback IDs and callback types are intentionally absent from the API.
        let repository = FaultRepository(LockState(targetSelections: [target], rules: [oneShot()]))
        for _ in 0..<3 {
            try LockLifecycle(repository: repository).reconcile(at: start.addingTimeInterval(1800), apply: {
                XCTAssertEqual($0, [self.target])
            })
        }
    }

    func testAdjacentRuleAppliesItsOwnTargetsAtBoundary() throws {
        let nextTarget = LockTargetSelectionRef(displayName: "Other apps")
        let next = LockRule(kind: .fixedDateTime, startsAt: start.addingTimeInterval(3600), duration: 3600, targetSelectionID: nextTarget.id)
        let repository = FaultRepository(LockState(targetSelections: [target, nextTarget], rules: [oneShot(), next]))
        try LockLifecycle(repository: repository).reconcile(at: next.single!.startsAt, apply: { XCTAssertEqual($0, [nextTarget]) })
    }

    func testRecurringRuleUsesCurrentOccurrenceAfterMidnightAndNextWeek() throws {
        let rule = recurring()
        let state = LockState(targetSelections: [target], rules: [rule])
        for dayOffset in [1.0, 8] {
            let now = start.addingTimeInterval(dayOffset * 86400 - 20 * 3600) // Friday 03:00
            let lock = try XCTUnwrap(state.activeLocks(at: now).first)
            XCTAssertEqual(lock.startedAt, start.addingTimeInterval((dayOffset - 1) * 86400))
            XCTAssertEqual(lock.endsAt, lock.startedAt.addingTimeInterval(8 * 3600))
        }
        XCTAssertTrue(state.activeLocks(at: start.addingTimeInterval(8 * 3600)).isEmpty)
    }

    func testOverlappingRecurringRulesUnionAndDeduplicateTargets() throws {
        let other = LockTargetSelectionRef(displayName: "Other")
        var later = recurring()
        later.id = UUID()
        later.targetSelectionID = other.id
        var recurrence = later.recurrence!; recurrence.endsAt = TimeOfDay(hour: 8, minute: 0); later.schedule = .recurring(recurrence)
        var duplicate = recurring()
        duplicate.id = UUID()
        let state = LockState(targetSelections: [target, other], rules: [recurring(), later, duplicate])
        XCTAssertEqual(Set(try state.selectionsToShield(at: start).map(\.id)), [target.id, other.id])
        XCTAssertEqual(try state.selectionsToShield(at: start.addingTimeInterval(8 * 3600)), [other])
    }

    func testDisabledRuleAndEmptyStateClearResidualShield() throws {
        var disabled = oneShot()
        disabled.status = .disabled
        for state in [LockState(), LockState(targetSelections: [target], rules: [disabled])] {
            try LockLifecycle(repository: FaultRepository(state)).reconcile(at: start, apply: { XCTAssertTrue($0.isEmpty) })
        }
    }

    func testReadFailureDoesNotChangeShieldAndNextReadCanRecover() throws {
        let repository = FaultRepository(LockState(rules: [oneShot()]))
        repository.failRead = true
        XCTAssertThrowsError(try LockLifecycle(repository: repository).reconcile(at: start, apply: { _ in XCTFail("Changed shield after read failure") }))
        repository.failRead = false
        try LockLifecycle(repository: repository).reconcile(at: start.addingTimeInterval(3600), apply: { XCTAssertTrue($0.isEmpty) })
    }

    func testMissingActiveTargetIsAnErrorInsteadOfPartialApply() throws {
        let repository = FaultRepository(LockState(rules: [oneShot()]))
        XCTAssertThrowsError(try LockLifecycle(repository: repository).reconcile(at: start, apply: { _ in XCTFail("Partial apply") }))
    }

    func testNoStateWriteIsRequiredToApplyOrClearAndApplyFailureCanRetry() throws {
        let repository = FaultRepository(LockState(targetSelections: [target], rules: [oneShot()]))
        repository.failWrite = true
        let lifecycle = LockLifecycle(repository: repository)
        XCTAssertThrowsError(try lifecycle.reconcile(at: start, apply: { _ in throw Fault.failure }))
        try lifecycle.reconcile(at: start, apply: { XCTAssertEqual($0, [self.target]) })
        try lifecycle.reconcile(at: start.addingTimeInterval(3600), apply: { XCTAssertTrue($0.isEmpty) })
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testCurrentTimeIsSampledAfterWaitingForRepository() throws {
        let end = Date().addingTimeInterval(0.025)
        let rule = LockRule(kind: .immediate, startsAt: end.addingTimeInterval(-3600), duration: 3600, targetSelectionID: target.id)
        let repository = FaultRepository(LockState(targetSelections: [target], rules: [rule]))
        repository.beforeLoad = { Thread.sleep(forTimeInterval: 0.05) }
        try LockLifecycle(repository: repository).reconcile(apply: { XCTAssertTrue($0.isEmpty) })
    }

    func testFailedMutationCannotLeakIntoLaterSuccessfulSave() async throws {
        let repository = FaultRepository(LockState())
        let store = LockStore(repository: repository)
        repository.failWrite = true
        do {
            _ = try await store.createRule(.now(duration: 3600, targetSelectionID: target.id), now: start)
            XCTFail("Expected write failure")
        } catch {}
        repository.failWrite = false
        _ = try await store.saveTargetSelection(target)
        let state = try await store.snapshot()
        XCTAssertTrue(state.rules.isEmpty)
    }

    func testActorEntryPointAppliesBeforeReturning() async throws {
        let store = LockStore(repository: FaultRepository(LockState()))
        let applied = AppliedFlag()
        _ = try await store.reconcile(at: start, apply: { _ in applied.value = true }, record: { _ in })
        XCTAssertTrue(applied.value)
    }

    func testSecondPrecisionAndFractionalRoundingShareTheMonitoringDeadline() throws {
        let rule = try LockPlanner().makeRule(from: .now(duration: 901.125, targetSelectionID: target.id),
            now: start.addingTimeInterval(0.75), existingRules: [])
        let components = rule.single!.monitoringComponents()
        XCTAssertEqual(Calendar.current.date(from: components.end), rule.single!.endsAt)
        XCTAssertEqual(rule.single!.startsAt, start)
        XCTAssertEqual(rule.single!.endsAt, start.addingTimeInterval(902))
        var future = oneShot()
        var single = future.single!
        single.startsAt = start.addingTimeInterval(0.125)
        single.duration = 900.75
        future.schedule = .single(single)
        let rounded = future.normalizedForMonitoring()
        XCTAssertGreaterThanOrEqual(rounded.single!.duration, future.single!.duration)
        XCTAssertGreaterThanOrEqual(rounded.single!.startsAt, future.single!.startsAt)
    }

    private func oneShot() -> LockRule {
        LockRule(kind: .fixedDateTime, startsAt: start, duration: 3600, targetSelectionID: target.id)
    }

    private func recurring() -> LockRule {
        LockRule(
            recurrence: RecurrenceRule(weekdays: [.thursday], startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC"), targetSelectionID: target.id)
    }
}

private enum Fault: Error { case failure }
private final class FaultRepository: LockRepository, @unchecked Sendable {
    private var state: LockState
    var failRead = false
    var failWrite = false
    var saveCount = 0
    var beforeLoad: (() -> Void)?
    init(_ state: LockState) { self.state = state }
    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T { try body() }
    func load() throws -> LockState {
        beforeLoad?()
        if failRead { throw Fault.failure }
        return state
    }
    func save(_ state: LockState) throws {
        saveCount += 1
        if failWrite { throw Fault.failure }
        self.state = state
    }
}
private final class AppliedFlag: @unchecked Sendable { var value = false }
