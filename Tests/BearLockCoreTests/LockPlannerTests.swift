import XCTest
@testable import BearLockCore

final class LockPlannerTests: XCTestCase {
    private let targetID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testRecurringEditValidatesTheDraftEnabledState() throws {
        let planner = LockPlanner()
        let now = date("2026-08-27T05:00:00Z")
        let recurrence = RecurrenceRule(weekdays: [.thursday], startsAt: TimeOfDay(hour: 6, minute: 0), endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC")
        let original = try planner.makeRule(from: .recurring(recurrence: recurrence, targetSelectionID: targetID), now: now, existingState: LockState())
        let conflict = try planner.makeRule(from: .fixed(startsAt: date("2026-08-27T06:15:00Z"), duration: 900, targetSelectionID: targetID), now: now, existingState: LockState())
        let disabled = try planner.validateRecurringReplacement(original, replacing: original, now: now, existingState: LockState(rules: [original, conflict]), enabled: false)
        XCTAssertEqual(disabled.status, .disabled)
        XCTAssertEqual(original.status, .scheduled)
        XCTAssertThrowsError(try planner.validateRecurringReplacement(disabled, replacing: disabled, now: now, existingState: LockState(rules: [disabled, conflict]), enabled: true))
        let enabled = try planner.validateRecurringReplacement(disabled, replacing: disabled, now: now, existingState: LockState(rules: [disabled]), enabled: true)
        XCTAssertEqual(enabled.status, .scheduled)
        XCTAssertEqual(enabled.id, original.id)
    }

    func testImmediateLockUsesCurrentTime() throws {
        let planner = LockPlanner()
        let now = date("2026-08-27T05:00:00Z")

        let rule = try planner.makeRule(
            from: .now(duration: 2 * 60 * 60, targetSelectionID: targetID),
            now: now,
            existingState: LockState()
        )
        let active = rule.occurrence(containing: now)!

        XCTAssertEqual(rule.kind, .immediate)
        XCTAssertEqual(rule.single!.startsAt, now)
        XCTAssertEqual(rule.single!.endsAt, date("2026-08-27T07:00:00Z"))
        XCTAssertEqual(active.startedAt, now)
        XCTAssertEqual(active.endsAt, date("2026-08-27T07:00:00Z"))
    }

    func testNonPositiveImmediateDurationIsRejected() {
        let planner = LockPlanner()

        XCTAssertThrowsError(
            try planner.makeRule(
                from: .now(duration: 0, targetSelectionID: targetID),
                now: date("2026-08-27T05:00:00Z"),
                existingState: LockState()
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .nonPositiveDuration)
        }
    }

    func testImmediateLockOverlappingActiveLockIsRejected() {
        let planner = LockPlanner()
        let now = date("2026-08-27T05:30:00Z")
        let active = LockRule(
            kind: .immediate,
            startsAt: date("2026-08-27T05:00:00Z"),
            duration: 3600,
            targetSelectionID: targetID
        )

        XCTAssertThrowsError(
            try planner.makeRule(
                from: .now(duration: 60 * 60, targetSelectionID: targetID),
                now: now,
                existingState: LockState(rules: [active])
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
    }

    func testDelayedLockComputesConcreteStartAndEnd() throws {
        let planner = LockPlanner()
        let now = date("2026-08-27T05:00:00Z")

        let rule = try planner.makeRule(
            from: .delayed(delay: 30 * 60, duration: 2 * 60 * 60, targetSelectionID: targetID),
            now: now,
            existingState: LockState()
        )

        XCTAssertEqual(rule.kind, .delayed)
        XCTAssertEqual(rule.single!.startsAt, date("2026-08-27T05:30:00Z"))
        XCTAssertEqual(rule.single!.endsAt, date("2026-08-27T07:30:00Z"))
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

    func testOverlappingScheduledLocksAreRejected() throws {
        let planner = LockPlanner()
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
                existingState: LockState(rules: [existing])
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
    }

    func testFutureScheduledLockReplacementIsAllowed() throws {
        let planner = LockPlanner()
        let now = date("2026-08-27T05:00:00Z")
        let original = LockRule(
            kind: .fixedDateTime,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )
        var replacement = original
        var single = replacement.single!
        single.startsAt = date("2026-08-27T07:00:00Z")
        single.duration = 2 * 60 * 60
        replacement.schedule = .single(single)

        let validated = try planner.validateScheduledReplacement(
            replacement,
            replacing: original,
            now: now,
            existingState: LockState(rules: [original])
        )

        XCTAssertEqual(validated.id, original.id)
        XCTAssertEqual(validated.single!.startsAt, date("2026-08-27T07:00:00Z"))
        XCTAssertEqual(validated.single!.endsAt, date("2026-08-27T09:00:00Z"))
        XCTAssertEqual(validated.status, .scheduled)
    }

    func testStartedScheduledLockReplacementIsRejected() {
        let planner = LockPlanner()
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
                existingState: LockState(rules: [original])
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .ruleAlreadyStarted)
        }
    }

    func testReplacementOverlappingAnotherRuleIsRejected() {
        let planner = LockPlanner()
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
        var single = replacement.single!
        single.startsAt = date("2026-08-27T08:30:00Z")
        replacement.schedule = .single(single)

        XCTAssertThrowsError(
            try planner.validateScheduledReplacement(
                replacement,
                replacing: original,
                now: now,
                existingState: LockState(rules: [original, other])
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .overlappingLock)
        }
    }

    func testFindsScheduledRuleContainingDate() {
        let rule = LockRule(
            kind: .delayed,
            startsAt: date("2026-08-27T06:00:00Z"),
            duration: 60 * 60,
            targetSelectionID: targetID
        )

        let found = LockState(rules: [rule]).activeLocks(at: date("2026-08-27T06:30:00Z"))

        XCTAssertEqual(found, [rule.occurrence(containing: date("2026-08-27T06:30:00Z"))!])
    }

    func testRecurringReplacementRecomputesNextOccurrenceAndKeepsRuleID() throws {
        let planner = LockPlanner()
        let ruleID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let original = LockRule(
            id: ruleID,
            recurrence: RecurrenceRule(
                weekdays: [.thursday],
                startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0),
                timeZoneIdentifier: "UTC"
            ),
            targetSelectionID: targetID
        )
        var replacement = original
        replacement.schedule = .recurring(RecurrenceRule(
            weekdays: [.friday],
            startsAt: TimeOfDay(hour: 22, minute: 0),
            endsAt: TimeOfDay(hour: 6, minute: 0),
            timeZoneIdentifier: "UTC"
        ))

        let validated = try planner.validateRecurringReplacement(
            replacement,
            replacing: original,
            now: date("2026-08-27T12:00:00Z"),
            existingState: LockState(rules: [original])
        )

        XCTAssertEqual(validated.id, ruleID)
        XCTAssertEqual(validated.kind, .recurring)
        XCTAssertEqual(validated.nextInterval(after: date("2026-08-27T12:00:00Z"))!.start, date("2026-08-28T22:00:00Z"))
        XCTAssertEqual(validated.nextInterval(after: date("2026-08-27T12:00:00Z"))!.end, date("2026-08-29T06:00:00Z"))
        XCTAssertEqual(validated.status, .scheduled)
    }

    func testRecurringReplacementWithNoWeekdaysIsRejected() {
        let planner = LockPlanner()
        let original = LockRule(
            recurrence: RecurrenceRule(
                weekdays: [.thursday],
                startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0),
                timeZoneIdentifier: "UTC"
            ),
            targetSelectionID: targetID
        )
        var replacement = original
        replacement.schedule = .recurring(RecurrenceRule(
            weekdays: [],
            startsAt: TimeOfDay(hour: 22, minute: 0),
            endsAt: TimeOfDay(hour: 6, minute: 0),
            timeZoneIdentifier: "UTC"
        ))

        XCTAssertThrowsError(
            try planner.validateRecurringReplacement(
                replacement,
                replacing: original,
                now: date("2026-08-27T12:00:00Z"),
                existingState: LockState(rules: [original])
            )
        ) { error in
            XCTAssertEqual(error as? LockValidationError, .emptyWeekdays)
        }
    }

    func testDisablingActiveRecurringRuleIsRejected() throws {
        let planner = LockPlanner()
        let ruleID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let rule = LockRule(
            id: ruleID,
            recurrence: RecurrenceRule(
                weekdays: [.thursday],
                startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0),
                timeZoneIdentifier: "UTC"
            ),
            targetSelectionID: targetID
        )
        XCTAssertThrowsError(try planner.validateRecurringReplacement(rule, replacing: rule,
            now: date("2026-08-27T23:30:00Z"), existingState: LockState(rules: [rule]), enabled: false)) {
            XCTAssertEqual($0 as? LockValidationError, .activeLockIsImmutable)
        }
    }

    func testExpiredOneShotDoesNotConflictWithANewRecurringSchedule() throws {
        let targetID = UUID()
        let old = LockRule(kind: .fixedDateTime, startsAt: date("2026-09-03T23:00:00Z"), duration: 3600, targetSelectionID: targetID)
        let recurrence = RecurrenceRule(weekdays: [.thursday], startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC")
        XCTAssertNoThrow(try LockPlanner().makeRule(from: .recurring(recurrence: recurrence, targetSelectionID: targetID),
            now: date("2026-09-10T12:00:00Z"), existingState: LockState(rules: [old])))
    }

    func testOneShotConflictUsesNextRecurringOccurrenceInsteadOfInitialRegistrationDate() {
        let targetID = UUID()
        let recurrence = RecurrenceRule(weekdays: [.thursday], startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "UTC")
        let recurring = LockRule(
            recurrence: recurrence, targetSelectionID: targetID)
        XCTAssertThrowsError(try LockPlanner().makeRule(from: .fixed(startsAt: date("2026-09-11T03:00:00Z"),
            duration: 3600, targetSelectionID: targetID), now: date("2026-09-10T12:00:00Z"), existingState: LockState(rules: [recurring]))) {
            XCTAssertEqual($0 as? LockValidationError, .overlappingLock)
        }
        XCTAssertNoThrow(try LockPlanner().makeRule(from: .fixed(startsAt: date("2026-09-11T07:00:00Z"),
            duration: 3600, targetSelectionID: targetID), now: date("2026-09-10T12:00:00Z"), existingState: LockState(rules: [recurring])))
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
