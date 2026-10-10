import XCTest
@testable import BearLockCore

final class WakePolicyTests: XCTestCase {
    func testFreeWakeKeepsLockUntilThirtyMinuteDeadline() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let rule = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 7200,
            targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [rule]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))

        let request = try await store.scheduleFreeWake(for: active, at: now)

        XCTAssertEqual(request.wakesAt, now.addingTimeInterval(30 * 60))
        XCTAssertNotNil(repository.state.activeLockForDisplay(at: request.wakesAt.addingTimeInterval(-1)))
        XCTAssertNil(repository.state.activeLockForDisplay(at: request.wakesAt))
        XCTAssertTrue(try repository.state.shieldSlotDecisions(at: request.wakesAt).isEmpty)
        XCTAssertEqual(MonitoringSchedule.desired(for: repository.state, at: now).filter {
            $0.name.hasPrefix("bearlock.wake.")
        }.count, 1)
    }

    func testFreeWakeCanBeCancelledAndIsUnavailableInsideThirtyMinutes() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let rule = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 7200,
            targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [rule]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))
        _ = try await store.scheduleFreeWake(for: active, at: now)
        try await store.cancelFreeWake(for: active, at: now.addingTimeInterval(10))
        XCTAssertTrue(repository.state.wakeState.requests.isEmpty)

        let nearEnd = rule.single!.endsAt.addingTimeInterval(-WakePolicy.freeDelay)
        do {
            _ = try await store.scheduleFreeWake(for: active, at: nearEnd)
            XCTFail("Expected free wake to be unavailable")
        } catch {
            XCTAssertEqual(error as? WakeError, .freeWakeUnavailable)
        }
    }

    func testFreeWakeAllowsRelockingAfterWakeWithoutRemovingRecurringRule() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let recurrence = RecurrenceRule(
            weekdays: Set(Weekday.allCases),
            startsAt: TimeOfDay(hour: 1, minute: 0),
            endsAt: TimeOfDay(hour: 3, minute: 0),
            timeZoneIdentifier: "UTC"
        )
        let recurring = LockRule(recurrence: recurrence, targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [recurring]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))

        let wake = try await store.scheduleFreeWake(for: active, at: now)
        do {
            _ = try await store.createRule(
                .now(duration: 10 * 60, targetSelectionID: UUID()),
                now: wake.wakesAt.addingTimeInterval(-1)
            )
            XCTFail("Relock must remain unavailable before the wake deadline")
        } catch {
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
        let relock = try await store.createRule(
            .now(duration: 10 * 60, targetSelectionID: UUID()),
            now: wake.wakesAt
        )

        XCTAssertNoThrow(try repository.state.validateEditable(recurring, at: wake.wakesAt))
        XCTAssertEqual(repository.state.rules.first, recurring)
        XCTAssertEqual(repository.state.activeLockForDisplay(at: wake.wakesAt)?.id, relock.id)
        XCTAssertEqual(repository.state.activeLockForDisplay(at: now.addingTimeInterval(24 * 60 * 60))?.id, recurring.id)
    }

    func testWakeDoesNotCancelScheduledRecurringDeletion() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let recurrence = RecurrenceRule(
            weekdays: Set(Weekday.allCases),
            startsAt: TimeOfDay(hour: 1, minute: 0),
            endsAt: TimeOfDay(hour: 3, minute: 0),
            timeZoneIdentifier: "UTC"
        )
        let recurring = LockRule(recurrence: recurrence, targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [recurring]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))

        try await store.deleteRule(id: recurring.id, now: now)
        let wake = try await store.scheduleFreeWake(for: active, at: now)

        XCTAssertEqual(repository.state.rules.first?.scheduledDeletionAt, active.endsAt)
        XCTAssertNil(repository.state.activeLockForDisplay(at: wake.wakesAt))
        XCTAssertNil(repository.state.activeLockForDisplay(at: now.addingTimeInterval(24 * 60 * 60)))
    }

    func testVerifiedPurchaseUnlocksOnceAndDuplicateDeliveryIsIdempotent() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let rule = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 7200,
            targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [rule]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))
        try await store.beginWakePurchase(for: active, at: now)

        let firstDelivery = try await store.deliverWakePurchase(transactionID: 42, at: now)
        XCTAssertEqual(firstDelivery, .unlocked)
        XCTAssertNil(repository.state.activeLockForDisplay(at: now))
        let duplicateDelivery = try await store.deliverWakePurchase(transactionID: 42, at: now)
        XCTAssertEqual(duplicateDelivery, .alreadyHandled)
        XCTAssertEqual(repository.state.wakeState.requests.count, 1)
    }

    func testPurchasedWakeAllowsImmediateRelocking() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let original = LockRule(
            kind: .immediate,
            startsAt: now.addingTimeInterval(-60),
            duration: 7200,
            targetSelectionID: UUID()
        )
        let repository = WakeMemoryRepository(state: LockState(rules: [original]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))
        try await store.beginWakePurchase(for: active, at: now)
        _ = try await store.deliverWakePurchase(transactionID: 42, at: now)

        let relock = try await store.createRule(.now(duration: 10 * 60, targetSelectionID: UUID()), now: now)

        XCTAssertEqual(repository.state.activeLockForDisplay(at: now)?.id, relock.id)
    }

    func testLateApprovalBecomesCreditForNextActiveLock() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let first = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 120,
            targetSelectionID: UUID())
        let secondStart = now.addingTimeInterval(600)
        let second = LockRule(kind: .fixedDateTime, startsAt: secondStart, duration: 3600,
            targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [first, second]))
        let store = LockStore(repository: repository)
        let firstActive = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))
        try await store.beginWakePurchase(for: firstActive, at: now)

        let delivery = try await store.deliverWakePurchase(transactionID: 77, at: secondStart)
        XCTAssertEqual(delivery, .credited)
        XCTAssertEqual(repository.state.wakeState.creditTransactionIDs, [77])
        let secondActive = try XCTUnwrap(repository.state.activeLockForDisplay(at: secondStart))
        try await store.useWakeCredit(for: secondActive, at: secondStart)
        XCTAssertNil(repository.state.activeLockForDisplay(at: secondStart))
        XCTAssertTrue(repository.state.wakeState.creditTransactionIDs.isEmpty)
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}

private final class WakeMemoryRepository: LockRepository, @unchecked Sendable {
    var state: LockState
    init(state: LockState) { self.state = state }
    func load() throws -> LockState { state }
    func save(_ state: LockState) throws { self.state = state }
}
