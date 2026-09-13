import XCTest
@testable import BearLockCore

final class LockStoreTests: XCTestCase {
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

    func testDeleteAllDayRecurringDuringLockPreservesOtherRuleThenReleases() async throws {
        let store = LockStore(repository: InMemoryLockRepository())
        let now = date("2026-09-13T09:00:00Z")
        let target = try await store.saveTargetSelection(LockTargetSelectionRef(displayName: "Apps"), now: now)
        let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases), startsAt: TimeOfDay(hour: 9, minute: 0),
            endsAt: TimeOfDay(hour: 9, minute: 0), timeZoneIdentifier: "UTC")
        let a = try await store.createRule(.recurring(recurrence: recurrence, targetSelectionID: target.id), now: now)
        let b = try await store.createRule(.recurring(recurrence: recurrence, targetSelectionID: target.id), now: now)
        try await store.deleteRule(id: a.id, now: now)
        var state = try await store.snapshot()
        XCTAssertEqual(state.rules, [b])
        XCTAssertEqual(try state.selectionsToShield(at: now), [target])
        try await store.deleteRule(id: b.id, now: now)
        state = try await store.snapshot()
        XCTAssertTrue(state.rules.isEmpty)
        XCTAssertTrue(try state.selectionsToShield(at: now).isEmpty)
        XCTAssertTrue(state.activeLocks(at: now.addingTimeInterval(86400)).isEmpty)
        XCTAssertTrue(MonitoringSchedule.desired(for: state.rules, at: now).isEmpty)
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
    private var state = LockState()

    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T { try body() }

    func load() throws -> LockState {
        state
    }

    func save(_ state: LockState) throws {
        self.state = state
    }
}
