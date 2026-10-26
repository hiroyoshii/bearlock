import XCTest
@testable import BearLockCore

final class WakePolicyTests: XCTestCase {
    func testProductionWakeClockIsSampledAfterFreshRepositoryRead() async throws {
        for cancel in [false, true] {
            let start = Date().addingTimeInterval(-60)
            let rule = LockRule(kind: .immediate, startsAt: start, duration: 7200, targetSelectionID: UUID())
            let lock = ActiveLock(id: rule.id, startedAt: start, endsAt: rule.single!.endsAt,
                                  targetSelectionID: rule.targetSelectionID)
            let repository = WakeMemoryRepository(state: LockState(rules: [rule]))
            repository.beforeLoad = {
                repository.beforeLoad = nil
                let boundary = Date().addingTimeInterval(0.05)
                if cancel {
                    repository.state.wakeState.requests = [WakeRequest(ruleID: rule.id,
                        occurrenceStartedAt: start, requestedAt: start, wakesAt: boundary, source: .delayed)]
                } else {
                    repository.state.rules[0].schedule = .single(SingleLockSchedule(kind: .immediate,
                        startsAt: start, duration: boundary.addingTimeInterval(WakePolicy.freeDelay).timeIntervalSince(start)))
                }
                // Force a deadline crossing during load, independently of actor/task scheduling before load.
                Thread.sleep(forTimeInterval: 0.1)
            }
            let store = LockStore(repository: repository)
            do {
                if cancel { try await store.cancelFreeWake(for: lock) }
                else { _ = try await store.scheduleFreeWake(for: lock) }
                XCTFail("Must revalidate using time after the repository read")
            } catch {
                XCTAssertEqual(error as? WakeError, cancel ? .activeLockNotFound : .freeWakeUnavailable)
            }
            XCTAssertEqual(repository.state.wakeState.requests.isEmpty, !cancel)
        }
    }

    func testFreeWakeRevalidatesDisabledOrDeletedRuleWithoutTouchingOtherLocks() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let rule = LockRule(kind: .immediate, startsAt: now, duration: 7200, targetSelectionID: UUID())
        let confirmed = ActiveLock(id: rule.id, startedAt: now, endsAt: now.addingTimeInterval(7200),
                                   targetSelectionID: rule.targetSelectionID)
        for deletion in [false, true] {
            var changed = rule
            if deletion { changed.scheduledDeletionAt = now } else { changed.status = .disabled }
            let request = WakeRequest(ruleID: rule.id, occurrenceStartedAt: now, requestedAt: now,
                                      wakesAt: now.addingTimeInterval(1800), source: .delayed)
            let original = LockState(rules: [changed], wakeState: WakeState(requests: [request]))
            let repository = WakeMemoryRepository(state: original)
            let store = LockStore(repository: repository)
            do { _ = try await store.scheduleFreeWake(for: confirmed, at: now); XCTFail("Expected stale occurrence rejection") }
            catch { XCTAssertEqual(error as? WakeError, .activeLockNotFound) }
            do { try await store.cancelFreeWake(for: confirmed, at: now); XCTFail("Expected stale occurrence rejection") }
            catch { XCTAssertEqual(error as? WakeError, .activeLockNotFound) }
            XCTAssertEqual(repository.state, original)
        }
    }

    func testFreeWakeKeepsLockUntilThirtyMinuteDeadline() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let rule = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 7200,
            targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [rule]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))

        let request = try await store.scheduleFreeWake(for: active, at: now)

        XCTAssertEqual(request.wakesAt, now.addingTimeInterval(30 * 60))
        let display = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))
        XCTAssertEqual(display.endsAt, request.wakesAt)
        XCTAssertEqual(display.remainingTime(at: now), 30 * 60)
        XCTAssertEqual(repository.state.displayInterval(for: rule, at: now)?.end, request.wakesAt)
        XCTAssertEqual(repository.state.rules.first?.single?.endsAt, rule.single?.endsAt)
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
        XCTAssertEqual(repository.state.activeLockForDisplay(at: now.addingTimeInterval(10))?.endsAt, rule.single?.endsAt)
        XCTAssertEqual(repository.state.displayInterval(for: rule, at: now.addingTimeInterval(10))?.end, rule.single?.endsAt)

        let nearEnd = rule.single!.endsAt.addingTimeInterval(-WakePolicy.freeDelay)
        do {
            _ = try await store.scheduleFreeWake(for: active, at: nearEnd)
            XCTFail("Expected free wake to be unavailable")
        } catch {
            XCTAssertEqual(error as? WakeError, .freeWakeUnavailable)
        }
    }

    func testDisplaySelectsLatestEffectiveEndAndRetainsWokenScheduleInterval() throws {
        let now = date("2026-09-20T01:00:00Z")
        let target = UUID()
        let longer = LockRule(kind: .delayed, startsAt: now, duration: 7200, targetSelectionID: target)
        let shorter = LockRule(kind: .delayed, startsAt: now, duration: 3600, targetSelectionID: target)
        let request = WakeRequest(ruleID: longer.id, occurrenceStartedAt: now, requestedAt: now,
                                  wakesAt: now.addingTimeInterval(1800), source: .delayed)
        let state = LockState(rules: [longer, shorter], wakeState: WakeState(requests: [request]))
        // Legacy overlapping rules are still evaluated; a display must use the latest actual deadline.
        XCTAssertEqual(state.activeLockForDisplay(at: now)?.id, shorter.id)
        XCTAssertEqual(state.activeLockForDisplay(at: now)?.endsAt, shorter.single?.endsAt)
        let afterWake = now.addingTimeInterval(1800)
        XCTAssertFalse(state.activeLocks(at: afterWake).contains { $0.id == longer.id })
        XCTAssertEqual(state.displayInterval(for: longer, at: afterWake)?.end, request.wakesAt)
        XCTAssertEqual(state.rules.first?.single?.endsAt, now.addingTimeInterval(7200))
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

    func testRecurringEditingUsesWakeDeadlineAndCancellationRestoresOriginalEnd() async throws {
        let now = date("2026-09-20T01:00:00Z")
        let recurring = LockRule(recurrence: RecurrenceRule(
            weekdays: Set(Weekday.allCases),
            startsAt: TimeOfDay(hour: 1, minute: 0),
            endsAt: TimeOfDay(hour: 3, minute: 0),
            timeZoneIdentifier: "UTC"
        ), targetSelectionID: UUID())
        let repository = WakeMemoryRepository(state: LockState(rules: [recurring]))
        let store = LockStore(repository: repository)
        let active = try XCTUnwrap(repository.state.activeLockForDisplay(at: now))
        let wake = try await store.scheduleFreeWake(for: active, at: now)

        XCTAssertThrowsError(try repository.state.validateEditable(recurring, at: wake.wakesAt.addingTimeInterval(-1))) {
            XCTAssertEqual($0 as? LockValidationError, .activeLockIsImmutable)
        }
        // The original occurrence still exists, but must not disable the editor after wake.
        XCTAssertNotNil(recurring.occurrence(containing: wake.wakesAt))
        XCTAssertNoThrow(try repository.state.validateEditable(recurring, at: wake.wakesAt))
        XCTAssertNoThrow(try repository.state.validateEditable(recurring, at: active.endsAt.addingTimeInterval(-1)))
        XCTAssertThrowsError(try repository.state.validateEditable(recurring, at: now.addingTimeInterval(24 * 60 * 60)))

        try await store.cancelFreeWake(for: active, at: wake.wakesAt.addingTimeInterval(-1))
        XCTAssertThrowsError(try repository.state.validateEditable(recurring, at: wake.wakesAt))
        XCTAssertNoThrow(try repository.state.validateEditable(recurring, at: active.endsAt))
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
    var beforeLoad: (() -> Void)?
    init(state: LockState) { self.state = state }
    func load() throws -> LockState { beforeLoad?(); return state }
    func save(_ state: LockState) throws { self.state = state }
}
