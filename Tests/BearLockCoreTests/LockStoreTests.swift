import XCTest
@testable import BearLockCore

final class LockStoreTests: XCTestCase {
    func testRecordingRecentTargetAddsItToHistory() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let target = LockTargetSelectionRef(displayName: "Social", tokenData: Data([1, 2, 3]))
        let savedTarget = try await store.saveTargetSelection(target)
        let usedAt = date("2026-08-27T10:00:00Z")

        try await store.recordRecentLockTarget(targetSelectionID: savedTarget.id, usedAt: usedAt)

        let state = await store.snapshot()
        XCTAssertEqual(state.recentLockTargets.count, 1)
        XCTAssertEqual(state.recentLockTargets.first?.targetSelectionID, savedTarget.id)
        XCTAssertEqual(state.recentLockTargets.first?.lastUsedAt, usedAt)
        XCTAssertFalse(state.recentLockTargets.first?.isPinned ?? true)
    }

    func testRecordingEquivalentTargetUpdatesExistingHistoryEntry() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
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

        let state = await store.snapshot()
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
        let store = try LockStore(repository: repository)
        let target = try await store.saveTargetSelection(
            LockTargetSelectionRef(displayName: "Social", tokenData: Data([7, 8, 9]))
        )
        try await store.recordRecentLockTarget(targetSelectionID: target.id, usedAt: date("2026-08-27T09:00:00Z"))
        let rule = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-28T10:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: target.id
        )
        try await store.addRule(rule)
        let stateBeforeDeletion = await store.snapshot()
        let recentID = try XCTUnwrap(stateBeforeDeletion.recentLockTargets.first?.id)

        try await store.deleteRecentLockTarget(id: recentID)

        let state = await store.snapshot()
        XCTAssertTrue(state.recentLockTargets.isEmpty)
        XCTAssertEqual(state.targetSelections, [target])
        XCTAssertEqual(state.rules, [rule])
    }

    func testOnlyThreeTargetsCanBePinned() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        var recentIDs: [UUID] = []

        for index in 0..<4 {
            let target = try await store.saveTargetSelection(
                LockTargetSelectionRef(displayName: "Target \(index)", tokenData: Data([UInt8(index)]))
            )
            try await store.recordRecentLockTarget(
                targetSelectionID: target.id,
                usedAt: date("2026-08-27T0\(index + 1):00:00Z")
            )
            let state = await store.snapshot()
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

    func testDeletingParentRuleDuringActiveLockIsRejected() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let ruleID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let targetID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let rule = LockRule(
            id: ruleID,
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T10:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        let active = ActiveLock(
            sourceRuleID: ruleID,
            startedAt: date("2026-08-27T10:00:00Z"),
            endsAt: date("2026-08-27T11:00:00Z"),
            targetSelectionID: targetID
        )

        try await store.addRule(rule)
        try await store.activate(active)

        do {
            try await store.deleteRule(id: ruleID, now: date("2026-08-27T10:30:00Z"))
            XCTFail("Expected active lock immutability to reject deleting the parent rule")
        } catch {
            XCTAssertEqual(error as? LockValidationError, .activeLockIsImmutable)
        }
    }

    func testCompletesActiveLockAtEndTime() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let targetID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let active = ActiveLock(
            sourceRuleID: nil,
            startedAt: date("2026-08-27T10:00:00Z"),
            endsAt: date("2026-08-27T11:00:00Z"),
            targetSelectionID: targetID
        )

        try await store.activate(active)
        let completed = try await store.completeActiveLock(at: date("2026-08-27T11:00:00Z"))
        let state = await store.snapshot()

        XCTAssertEqual(completed, active)
        XCTAssertNil(state.activeLock)
        XCTAssertEqual(state.completedLocks, [active])
    }

    func testClearActiveLockRemovesMatchingActiveLock() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let activeID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let targetID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let active = ActiveLock(
            id: activeID,
            sourceRuleID: nil,
            startedAt: date("2026-08-27T10:00:00Z"),
            endsAt: date("2026-08-27T11:00:00Z"),
            targetSelectionID: targetID
        )

        try await store.activate(active)
        try await store.clearActiveLock(id: activeID)

        let state = await store.snapshot()
        XCTAssertNil(state.activeLock)
    }

    func testReplacingStartedRuleIsRejected() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let ruleID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let targetID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let rule = LockRule(
            id: ruleID,
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T10:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        var replacement = rule
        replacement.duration = 2 * 60 * 60

        try await store.addRule(rule)

        do {
            try await store.replaceRule(replacement, now: date("2026-08-27T10:00:00Z"))
            XCTFail("Expected started rule replacement to be rejected")
        } catch {
            XCTAssertEqual(error as? LockValidationError, .ruleAlreadyStarted)
        }
    }

    func testCompletesExpiredOneShotRules() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let targetID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let expired = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T09:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        let future = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T12:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )

        try await store.addRule(expired)
        try await store.addRule(future)

        let completed = try await store.completeExpiredOneShotRules(at: date("2026-08-27T10:00:00Z"))
        let state = await store.snapshot()

        XCTAssertEqual(completed.map(\.id), [expired.id])
        XCTAssertEqual(state.rules.first(where: { $0.id == expired.id })?.status, .completed)
        XCTAssertEqual(state.rules.first(where: { $0.id == future.id })?.status, .scheduled)
    }

    func testReplacingRecurringRuleDuringActiveLockIsAllowedWithoutChangingActiveLock() async throws {
        let repository = InMemoryLockRepository()
        let store = try LockStore(repository: repository)
        let ruleID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let targetID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let rule = LockRule(
            id: ruleID,
            kind: .recurring,
            startsAt: date("2026-08-27T23:00:00Z"),
            duration: 8 * 60 * 60,
            recurrence: RecurrenceRule(
                weekdays: [.thursday],
                startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0),
                timeZoneIdentifier: "UTC"
            ),
            targetSelectionID: targetID
        )
        let active = ActiveLock(
            sourceRuleID: ruleID,
            startedAt: date("2026-08-27T23:00:00Z"),
            endsAt: date("2026-08-28T07:00:00Z"),
            targetSelectionID: targetID
        )
        var replacement = rule
        replacement.status = .disabled

        try await store.addRule(rule)
        try await store.activate(active)
        try await store.replaceRule(replacement, now: date("2026-08-27T23:30:00Z"))

        let state = await store.snapshot()
        XCTAssertEqual(state.rules.first(where: { $0.id == ruleID })?.status, .disabled)
        XCTAssertEqual(state.activeLock, active)
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}

private final class InMemoryLockRepository: LockRepository, @unchecked Sendable {
    private var state = LockState()

    func load() throws -> LockState {
        state
    }

    func save(_ state: LockState) throws {
        self.state = state
    }
}
