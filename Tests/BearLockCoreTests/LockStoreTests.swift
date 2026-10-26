import XCTest
@testable import BearLockCore

final class LockStoreTests: XCTestCase {
    func testHistoryPinClockIsSampledInsideFreshRead() async throws {
        let target = LockTargetSelectionRef(displayName: "A")
        let recent = RecentLockTarget(targetSelectionID: target.id, lastUsedAt: Date())
        let repository = InMemoryLockRepository(state: LockState(targetSelections: [target], recentLockTargets: [recent]))
        let store = LockStore(repository: repository)
        var readFinished = Date.distantPast
        repository.beforeLoad = { _ in
            Thread.sleep(forTimeInterval: 0.1)
            readFinished = Date()
        }
        try await store.setRecentLockTargetPinned(id: recent.id, pinned: true)
        let state = try await store.snapshot()
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(state.recentLockTargets.first?.pinnedAt), readFinished)
    }
    func testRelativeCreateSamplesTimeAfterFreshRead() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        var readFinished = Date.distantPast
        repository.beforeLoad = { _ in
            Thread.sleep(forTimeInterval: 0.1)
            readFinished = Date()
        }
        let rule = try await store.createRule(.delayed(delay: 3600, duration: 300, targetSelectionID: UUID()))
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(rule.single).startsAt, readFinished.addingTimeInterval(3600))
    }

    func testEditAndDeleteRevalidateTimeAfterFreshReadCrossesStart() async throws {
        for deleting in [false, true] {
            let rule = LockRule(kind: .fixedDateTime, startsAt: Date().addingTimeInterval(3600),
                duration: 300, targetSelectionID: UUID())
            let repository = InMemoryLockRepository(state: LockState(rules: [rule]))
            let store = LockStore(repository: repository)
            repository.beforeLoad = { state in
                state.rules[0].schedule = .single(SingleLockSchedule(kind: .fixedDateTime,
                    startsAt: Date().addingTimeInterval(0.05), duration: 300))
                Thread.sleep(forTimeInterval: 0.1)
            }
            do {
                if deleting { try await store.deleteRule(id: rule.id) }
                else { try await store.replaceRule(rule) }
                XCTFail("A schedule started during read must be immutable")
            } catch { XCTAssertEqual(error as? LockValidationError, .activeLockIsImmutable) }
            let state = try await store.snapshot()
            XCTAssertEqual(state.rules.count, 1)
            XCTAssertLessThan(try XCTUnwrap(state.rules.first?.single).startsAt, Date())
        }
    }

    func testRecordingRecentTargetAddsItToHistory() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        let target = LockTargetSelectionRef(displayName: "Social", tokenData: Data([1, 2, 3]))
        let savedTarget = try await store.saveTargetSelection(target)
        let usedAt = date("2026-08-27T10:00:00Z")

        try await store.recordRecentLockTarget(targetSelectionID: savedTarget.id, usedAt: usedAt)

        let state = try await store.snapshot()
        XCTAssertEqual(state.recentLockTargets.count, 1)
        XCTAssertEqual(state.recentLockTargets.first?.targetSelectionID, savedTarget.id)
        XCTAssertEqual(state.recentLockTargets.first?.lastUsedAt, usedAt)
        XCTAssertFalse(state.recentLockTargets.first?.isPinned ?? true)
    }

    func testRecordingEquivalentTargetUpdatesExistingHistoryEntry() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        let first = try await store.saveTargetSelection(
            LockTargetSelectionRef(displayName: "First", tokenData: Data([4, 5, 6]))
        )
        try await store.recordRecentLockTarget(
            targetSelectionID: first.id,
            usedAt: date("2026-08-27T09:00:00Z")
        )
        let equivalent = try await store.saveTargetSelection(
            LockTargetSelectionRef(displayName: "Equivalent", tokenData: Data([4, 5, 6]))
        )

        try await store.recordRecentLockTarget(
            targetSelectionID: equivalent.id,
            usedAt: date("2026-08-27T11:00:00Z")
        )

        let state = try await store.snapshot()
        XCTAssertEqual(equivalent.id, first.id)
        XCTAssertEqual(state.recentLockTargets.count, 1)
        XCTAssertEqual(state.recentLockTargets.first?.lastUsedAt, date("2026-08-27T11:00:00Z"))
    }

    func testPinnedTargetsDisplayBeforeRecentTargetsWithThreeItemLimit() {
        let oldPinned = RecentLockTarget(
            targetSelectionID: UUID(),
            lastUsedAt: date("2026-08-27T06:00:00Z"),
            pinnedAt: date("2026-08-27T08:00:00Z")
        )
        let newPinned = RecentLockTarget(
            targetSelectionID: UUID(),
            lastUsedAt: date("2026-08-27T12:00:00Z"),
            pinnedAt: date("2026-08-27T09:00:00Z")
        )
        let recent = RecentLockTarget(
            targetSelectionID: UUID(),
            lastUsedAt: date("2026-08-27T11:00:00Z")
        )
        let older = RecentLockTarget(
            targetSelectionID: UUID(),
            lastUsedAt: date("2026-08-27T10:00:00Z")
        )
        let state = LockState(recentLockTargets: [older, recent, newPinned, oldPinned])

        XCTAssertEqual(
            state.displayedRecentLockTargets().map(\.id),
            [oldPinned.id, newPinned.id, recent.id]
        )
    }

    func testDeletingRecentTargetDoesNotDeleteSelectionOrRule() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        let target = try await store.saveTargetSelection(
            LockTargetSelectionRef(displayName: "Social", tokenData: Data([7, 8, 9]))
        )
        try await store.recordRecentLockTarget(targetSelectionID: target.id, usedAt: date("2026-08-27T09:00:00Z"))
        let rule = try await store.createRule(.fixed(startsAt: date("2026-08-28T10:00:00Z"),
            duration: 3600, targetSelectionID: target.id), now: date("2026-08-27T09:00:00Z"))
        let stateBeforeDeletion = try await store.snapshot()
        let recentID = try XCTUnwrap(stateBeforeDeletion.recentLockTargets.first?.id)

        try await store.deleteRecentLockTarget(id: recentID)

        let state = try await store.snapshot()
        XCTAssertTrue(state.recentLockTargets.isEmpty)
        XCTAssertEqual(state.targetSelections, [target])
        XCTAssertEqual(state.rules, [rule])
    }

    func testOnlyThreeTargetsCanBePinned() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        var recentIDs: [UUID] = []

        for index in 0..<4 {
            let target = try await store.saveTargetSelection(
                LockTargetSelectionRef(displayName: "Target \(index)", tokenData: Data([UInt8(index)]))
            )
            try await store.recordRecentLockTarget(
                targetSelectionID: target.id,
                usedAt: date("2026-08-27T0\(index + 1):00:00Z")
            )
            let state = try await store.snapshot()
            recentIDs.append(try XCTUnwrap(state.recentLockTargets.last?.id))
        }

        for (index, id) in recentIDs.prefix(3).enumerated() {
            try await store.setRecentLockTargetPinned(
                id: id,
                pinned: true,
                at: date("2026-08-27T1\(index):00:00Z")
            )
        }

        do {
            try await store.setRecentLockTargetPinned(
                id: recentIDs[3],
                pinned: true,
                at: date("2026-08-27T13:00:00Z")
            )
            XCTFail("Expected the fourth pinned target to be rejected")
        } catch {
            XCTAssertEqual(error as? RecentLockTargetError, .pinnedTargetLimitReached)
        }
    }

    func testActiveRulesRejectEditsAndSingleLocksRejectDeletion() async throws {
        // Both one-shot and recurring rules, including the overnight tail.
        for recurring in [false, true] {
            let repository = InMemoryLockRepository()
            let store = LockStore(repository: repository)
            let recurrence = RecurrenceRule(weekdays: [.thursday], startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC")
            let request: LockCreationRequest = recurring
                ? .recurring(recurrence: recurrence, targetSelectionID: UUID())
                : .fixed(startsAt: date("2026-08-27T23:00:00Z"), duration: 28800, targetSelectionID: UUID())
            let rule = try await store.createRule(request, now: date("2026-08-27T22:00:00Z"))
            for timestamp in ["2026-08-27T23:00:00Z", "2026-08-28T03:00:00Z", "2026-08-28T06:59:59Z"] {
                let now = date(timestamp)
                var draft = rule
                if var weekly = draft.recurrence {
                    weekly.endsAt = TimeOfDay(hour: 0, minute: 0)
                    draft.schedule = .recurring(weekly)
                } else { var single = draft.single!; single.duration = 3600; draft.schedule = .single(single) }
                draft.status = .disabled
                do {
                    try await store.replaceRule(draft, now: now)
                    XCTFail("An active rule was changed")
                } catch { XCTAssertEqual(error as? LockValidationError, .activeLockIsImmutable) }
                if !recurring {
                    do {
                        try await store.deleteRule(id: rule.id, now: now)
                        XCTFail("An active single lock was deleted")
                    } catch { XCTAssertEqual(error as? LockValidationError, .activeLockIsImmutable) }
                }
                let snapshot = try await store.snapshot()
                XCTAssertEqual(snapshot.rules, [rule])
            }
            // Exactly at the deadline, the rule is no longer active.
            try await store.deleteRule(id: rule.id, now: date("2026-08-28T07:00:00Z"))
            let snapshot = try await store.snapshot()
            XCTAssertTrue(snapshot.rules.isEmpty)
        }
    }

    func testDeleteLegacyOverlappingRecurringPreservesOtherRuleAndRejectsRestore() async throws {
        let now = date("2026-09-13T09:00:00Z")
        let currentEnd = date("2026-09-14T09:00:00Z")
        let nextEnd = date("2026-09-15T09:00:00Z")
        let target = LockTargetSelectionRef(displayName: "Apps")
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases), startsAt: TimeOfDay(hour: 9, minute: 0),
            endsAt: TimeOfDay(hour: 9, minute: 0), timeZoneIdentifier: "UTC")
        let a = LockRule(recurrence: recurrence, targetSelectionID: target.id)
        let b = LockRule(recurrence: recurrence, targetSelectionID: target.id)
        let store = LockStore(repository: InMemoryLockRepository(state: LockState(targetSelections: [target], rules: [a, b])))
        try await store.deleteRule(id: a.id, now: now)
        do {
            try await store.cancelScheduledDeletion(id: a.id, now: now.addingTimeInterval(60))
            XCTFail("Restoring the legacy overlapping rule must be rejected")
        } catch { XCTAssertEqual(error as? LockValidationError, .overlappingLock) }
        var state = try await store.snapshot(at: now)
        XCTAssertEqual(state.rules.map(\.id), [a.id, b.id])
        XCTAssertEqual(state.rules.first?.scheduledDeletionAt, currentEnd)
        XCTAssertEqual(state.activeLocks(at: now).count, 2)
        XCTAssertEqual(try state.shieldSlotDecisions(at: now).count, 2)
        XCTAssertFalse(MonitoringSchedule.desired(for: state.rules, at: now).isEmpty)
        XCTAssertEqual(state.activeLocks(at: currentEnd).map(\.id), [b.id])
        XCTAssertEqual(try state.shieldSlotDecisions(at: currentEnd).map(\.selection), [target])
        XCTAssertTrue(MonitoringSchedule.desired(for: state.rules, at: currentEnd)
            .allSatisfy { !$0.name.contains(a.id.uuidString) })

        state = try await store.snapshot(at: currentEnd)
        XCTAssertEqual(state.rules, [b])
        XCTAssertEqual(state.activeLocks(at: currentEnd).map(\.id), [b.id])
        XCTAssertEqual(try state.shieldSlotDecisions(at: currentEnd).map(\.selection), [target])

        try await store.deleteRule(id: b.id, now: currentEnd)
        state = try await store.snapshot(at: currentEnd)
        XCTAssertEqual(state.rules.first?.scheduledDeletionAt, nextEnd)
        XCTAssertEqual(state.activeLocks(at: currentEnd).map(\.id), [b.id])
        state = try await store.snapshot(at: nextEnd)
        XCTAssertTrue(state.rules.isEmpty)
        XCTAssertTrue(MonitoringSchedule.desired(for: state.rules, at: nextEnd).isEmpty)
    }

    func testScheduledDeletionCancellationRejectsAConflictingFutureLock() async throws {
        let store = LockStore(repository: InMemoryLockRepository())
        let now = date("2026-09-13T09:00:00Z")
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases), startsAt: TimeOfDay(hour: 9, minute: 0),
            endsAt: TimeOfDay(hour: 9, minute: 0), timeZoneIdentifier: "UTC")
        let recurring = try await store.createRule(.recurring(recurrence: recurrence, targetSelectionID: UUID()), now: now)
        try await store.deleteRule(id: recurring.id, now: now)
        _ = try await store.createRule(.fixed(startsAt: date("2026-09-14T10:00:00Z"),
            duration: 3600, targetSelectionID: UUID()), now: now)

        do {
            try await store.cancelScheduledDeletion(id: recurring.id, now: now)
            XCTFail("A conflicting recurring schedule was restored")
        } catch {
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
        let state = try await store.snapshot(at: now)
        XCTAssertNotNil(state.rules.first { $0.id == recurring.id }?.scheduledDeletionAt)
    }

    func testScheduledDeletionCancellationRechecksFutureRecurringRules() async throws {
        let store = LockStore(repository: InMemoryLockRepository())
        let now = date("2026-09-13T09:00:00Z")
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases), startsAt: TimeOfDay(hour: 9, minute: 0),
            endsAt: TimeOfDay(hour: 9, minute: 0), timeZoneIdentifier: "UTC")
        let first = try await store.createRule(.recurring(recurrence: recurrence, targetSelectionID: UUID()), now: now)
        try await store.deleteRule(id: first.id, now: now)
        try await store.cancelScheduledDeletion(id: first.id, now: now) // No conflict: cancellation still works.
        try await store.deleteRule(id: first.id, now: now)
        let next = RecurrenceRule(weekdays: [.monday], startsAt: TimeOfDay(hour: 10, minute: 0),
            endsAt: TimeOfDay(hour: 11, minute: 0), timeZoneIdentifier: "UTC")
        _ = try await store.createRule(.recurring(recurrence: next, targetSelectionID: UUID()), now: now)
        let saved = try await store.snapshot(at: now)
        do {
            try await store.cancelScheduledDeletion(id: first.id, now: now)
            XCTFail("Deletion cancellation restored a weekly conflict")
        } catch { XCTAssertEqual(error as? LockValidationError, .overlappingLock) }
        let after = try await store.snapshot(at: now)
        XCTAssertEqual(after, saved)
    }

    func testScheduledDeletionCancellationKeepsWakeIdentityAndAllowsFreeSingleInterval() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        let now = date("2026-09-13T09:00:00Z")
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases), startsAt: TimeOfDay(hour: 9, minute: 0),
            endsAt: TimeOfDay(hour: 11, minute: 0), timeZoneIdentifier: "UTC")
        let rule = try await store.createRule(.recurring(recurrence: recurrence, targetSelectionID: UUID()), now: now)
        let lock = try XCTUnwrap(rule.occurrence(containing: now))
        _ = try await store.scheduleFreeWake(for: lock, at: now)
        try await store.deleteRule(id: rule.id, now: now)
        _ = try await store.createRule(.fixed(startsAt: now.addingTimeInterval(1800), duration: 900,
            targetSelectionID: UUID()), now: now)
        let saved = try await store.snapshot(at: now)
        try await store.cancelScheduledDeletion(id: rule.id, now: now)
        let restored = try await store.snapshot(at: now)
        XCTAssertNil(restored.rules.first { $0.id == rule.id }?.scheduledDeletionAt)
        XCTAssertEqual(restored.wakeState, saved.wakeState)
        XCTAssertEqual(restored.rules.map(\.id), saved.rules.map(\.id))
    }

    func testDisabledRecurringRuleCanBeEditedDuringItsTimeWindow() async throws {
        let repository = InMemoryLockRepository()
        let store = LockStore(repository: repository)
        let recurrence = RecurrenceRule(weekdays: [.thursday], startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC")
        var rule = try await store.createRule(.recurring(recurrence: recurrence, targetSelectionID: UUID()),
            now: date("2026-08-27T22:00:00Z"))
        rule.status = .disabled
        try await store.replaceRule(rule, now: date("2026-08-27T22:00:00Z"))
        var changedRecurrence = rule.recurrence!; changedRecurrence.endsAt = TimeOfDay(hour: 8, minute: 0); rule.schedule = .recurring(changedRecurrence)
        try await store.replaceRule(rule, now: date("2026-08-28T01:00:00Z"))
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.rules.first?.status, .disabled)
        XCTAssertTrue(snapshot.activeLocks(at: date("2026-08-28T01:00:00Z")).isEmpty)
    }

    func testStaleEditorCannotOverwriteDeletedRule() async throws {
        let store = LockStore(repository: InMemoryLockRepository())
        let now = date("2026-08-27T22:00:00Z")
        let rule = try await store.createRule(.delayed(delay: 3600, duration: 3600, targetSelectionID: UUID()), now: now)
        try await store.deleteRule(id: rule.id, now: now)
        do {
            try await store.replaceRule(rule, now: now)
            XCTFail("Deleted rule resurrected")
        } catch { XCTAssertEqual(error as? LockValidationError, .ruleNotFound) }
    }

    func testCreateAndReplaceValidateConflictsAgainstSavedRules() async throws {
        let store = LockStore(repository: InMemoryLockRepository())
        let now = date("2026-08-27T22:00:00Z")
        let request = LockCreationRequest.delayed(delay: 3600, duration: 3600, targetSelectionID: UUID())
        let first = try await store.createRule(request, now: now)
        do {
            _ = try await store.createRule(request, now: now)
            XCTFail("Overlap accepted")
        } catch { XCTAssertEqual(error as? LockValidationError, .overlappingLock) }
        var second = try await store.createRule(.delayed(delay: 7200, duration: 3600, targetSelectionID: UUID()), now: now)
        var single = second.single!
        single.startsAt = first.single!.startsAt
        second.schedule = .single(single)
        do {
            try await store.replaceRule(second, now: now)
            XCTFail("Overlapping edit accepted")
        } catch { XCTAssertEqual(error as? LockValidationError, .overlappingLock) }
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.rules.count, 2)
        XCTAssertNotEqual(snapshot.rules[1].single!.startsAt, first.single!.startsAt)
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}

private final class InMemoryLockRepository: LockRepository, @unchecked Sendable {
    private var state: LockState
    var beforeLoad: ((inout LockState) -> Void)?
    init(state: LockState = LockState()) { self.state = state }

    func load() throws -> LockState {
        if let beforeLoad {
            self.beforeLoad = nil
            beforeLoad(&state)
        }
        return state
    }

    func save(_ state: LockState) throws {
        self.state = state
    }
}
