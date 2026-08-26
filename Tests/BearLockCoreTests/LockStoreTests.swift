import XCTest
@testable import BearLockCore

final class LockStoreTests: XCTestCase {
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
