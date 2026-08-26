import XCTest
@testable import BearLockCore

final class LockPlannerTests: XCTestCase {
    private let targetID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testImmediateLockUsesCurrentTime() throws {
        let planner = LockPlanner(calendar: gregorianUTC)
        let now = date("2026-08-27T05:00:00Z")

        let rule = try planner.makeRule(
            from: .now(duration: 2 * 60 * 60, targetSelectionID: targetID),
            now: now,
            existingRules: [],
            activeLock: nil
        )
        let active = planner.activeLock(from: rule, intervalStart: now)

        XCTAssertEqual(rule.kind, .immediate)
        XCTAssertEqual(rule.startsAt, now)
        XCTAssertEqual(rule.endsAt, date("2026-08-27T07:00:00Z"))
        XCTAssertEqual(active.startedAt, now)
        XCTAssertEqual(active.endsAt, date("2026-08-27T07:00:00Z"))
    }

    func testNonPositiveImmediateDurationIsRejected() {
        let planner = LockPlanner(calendar: gregorianUTC)

        XCTAssertThrowsError(
            try planner.makeRule(
                from: .now(duration: 0, targetSelectionID: targetID),
                now: date("2026-08-27T05:00:00Z"),
                existingRules: [],
                activeLock: nil
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .nonPositiveDuration)
        }
    }

    func testImmediateLockOverlappingActiveLockIsRejected() {
        let planner = LockPlanner(calendar: gregorianUTC)
        let now = date("2026-08-27T05:30:00Z")
        let active = ActiveLock(
            sourceRuleID: nil,
            startedAt: date("2026-08-27T05:00:00Z"),
            endsAt: date("2026-08-27T06:00:00Z"),
            targetSelectionID: targetID
        )

        XCTAssertThrowsError(
            try planner.makeRule(
                from: .now(duration: 60 * 60, targetSelectionID: targetID),
                now: now,
                existingRules: [],
                activeLock: active
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
    }

    func testDelayedLockComputesConcreteStartAndEnd() throws {
        let planner = LockPlanner(calendar: gregorianUTC)
        let now = date("2026-08-27T05:00:00Z")

        let rule = try planner.makeRule(
            from: .delayed(delay: 30 * 60, duration: 2 * 60 * 60, targetSelectionID: targetID),
            now: now,
            existingRules: [],
            activeLock: nil
        )

        XCTAssertEqual(rule.kind, .delayed)
        XCTAssertEqual(rule.startsAt, date("2026-08-27T05:30:00Z"))
        XCTAssertEqual(rule.endsAt, date("2026-08-27T07:30:00Z"))
    }

    func testOvernightRecurringRuleProducesNextMorningEnd() throws {
        let recurrence = RecurrenceRule(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0),
            timeZoneIdentifier: "UTC"
        )

        let interval = try XCTUnwrap(recurrence.nextInterval(after: date("2026-08-27T12:00:00Z")))

        XCTAssertEqual(interval.start, date("2026-08-27T23:00:00Z"))
        XCTAssertEqual(interval.end, date("2026-08-28T07:00:00Z"))
        XCTAssertEqual(interval.duration, 8 * 60 * 60)
    }

    func testActiveLockSnapshotDoesNotChangeWhenParentRuleChanges() {
        let planner = LockPlanner(calendar: gregorianUTC)
        let ruleID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let originalRule = LockRule(
            id: ruleID,
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T23:00:00Z"),
            duration: 8 * 60 * 60,
            targetSelectionID: targetID
        )

        let active = planner.activeLock(from: originalRule)
        var editedRule = originalRule
        editedRule.duration = 60 * 60

        XCTAssertEqual(active.sourceRuleID, editedRule.id)
        XCTAssertEqual(active.endsAt, date("2026-08-28T07:00:00Z"))
        XCTAssertEqual(editedRule.endsAt, date("2026-08-28T00:00:00Z"))
    }

    func testOverlappingScheduledLocksAreRejected() throws {
        let planner = LockPlanner(calendar: gregorianUTC)
        let now = date("2026-08-27T05:00:00Z")
        let existing = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )

        XCTAssertThrowsError(
            try planner.makeRule(
                from: .fixed(startsAt: date("2026-08-27T06:30:00Z"), duration: 60 * 60, targetSelectionID: targetID),
                now: now,
                existingRules: [existing],
                activeLock: nil
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
    }

    func testFutureScheduledLockReplacementIsAllowed() throws {
        let planner = LockPlanner(calendar: gregorianUTC)
        let now = date("2026-08-27T05:00:00Z")
        let original = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        var replacement = original
        replacement.startsAt = date("2026-08-27T07:00:00Z")
        replacement.duration = 2 * 60 * 60

        let validated = try planner.validateScheduledReplacement(
            replacement,
            replacing: original,
            now: now,
            existingRules: [original],
            activeLock: nil
        )

        XCTAssertEqual(validated.id, original.id)
        XCTAssertEqual(validated.startsAt, date("2026-08-27T07:00:00Z"))
        XCTAssertEqual(validated.endsAt, date("2026-08-27T09:00:00Z"))
        XCTAssertEqual(validated.status, .scheduled)
    }

    func testStartedScheduledLockReplacementIsRejected() {
        let planner = LockPlanner(calendar: gregorianUTC)
        let original = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )

        XCTAssertThrowsError(
            try planner.validateScheduledReplacement(
                original,
                replacing: original,
                now: date("2026-08-27T06:00:00Z"),
                existingRules: [original],
                activeLock: nil
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .ruleAlreadyStarted)
        }
    }

    func testReplacementOverlappingAnotherRuleIsRejected() {
        let planner = LockPlanner(calendar: gregorianUTC)
        let now = date("2026-08-27T05:00:00Z")
        let original = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        let other = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T08:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        var replacement = original
        replacement.startsAt = date("2026-08-27T08:30:00Z")

        XCTAssertThrowsError(
            try planner.validateScheduledReplacement(
                replacement,
                replacing: original,
                now: now,
                existingRules: [original, other],
                activeLock: nil
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
    }

    func testFindsScheduledRuleContainingDate() {
        let planner = LockPlanner(calendar: gregorianUTC)
        let rule = LockRule(
            kind: .delayed,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )

        let found = planner.scheduledRuleContaining(date("2026-08-27T06:30:00Z"), in: [rule])

        XCTAssertEqual(found, rule)
    }

    func testRecurringReplacementRecomputesNextOccurrenceAndKeepsRuleID() throws {
        let planner = LockPlanner(calendar: gregorianUTC)
        let ruleID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let original = LockRule(
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
        var replacement = original
        replacement.recurrence = RecurrenceRule(
            weekdays: [.friday],
            startsAt: TimeOfDay(hour: 22, minute: 0),
            endsAt: TimeOfDay(hour: 6, minute: 0),
            timeZoneIdentifier: "UTC"
        )

        let validated = try planner.validateRecurringReplacement(
            replacement,
            replacing: original,
            now: date("2026-08-27T12:00:00Z"),
            existingRules: [original],
            activeLock: nil
        )

        XCTAssertEqual(validated.id, ruleID)
        XCTAssertEqual(validated.kind, .recurring)
        XCTAssertEqual(validated.startsAt, date("2026-08-28T22:00:00Z"))
        XCTAssertEqual(validated.endsAt, date("2026-08-29T06:00:00Z"))
        XCTAssertEqual(validated.status, .scheduled)
    }

    func testRecurringReplacementWithNoWeekdaysIsRejected() {
        let planner = LockPlanner(calendar: gregorianUTC)
        let original = LockRule(
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
        var replacement = original
        replacement.recurrence = RecurrenceRule(
            weekdays: [],
            startsAt: TimeOfDay(hour: 22, minute: 0),
            endsAt: TimeOfDay(hour: 6, minute: 0),
            timeZoneIdentifier: "UTC"
        )

        XCTAssertThrowsError(
            try planner.validateRecurringReplacement(
                replacement,
                replacing: original,
                now: date("2026-08-27T12:00:00Z"),
                existingRules: [original],
                activeLock: nil
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .emptyWeekdays)
        }
    }

    func testDisablingRecurringRulePreservesCurrentActiveLockSnapshot() throws {
        let planner = LockPlanner(calendar: gregorianUTC)
        let ruleID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
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
        let active = planner.activeLock(from: rule)

        let disabled = try planner.recurringRule(rule, enabled: false, now: date("2026-08-27T23:30:00Z"))

        XCTAssertEqual(disabled.status, .disabled)
        XCTAssertEqual(active.startedAt, date("2026-08-27T23:00:00Z"))
        XCTAssertEqual(active.endsAt, date("2026-08-28T07:00:00Z"))
    }

    private var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
