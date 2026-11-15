import XCTest
@testable import BearLockCore

final class DailyAllowanceTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testDailyAllowanceLimitCannotExceed60Minutes() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)

        for limit in [90, 120] {
            XCTAssertThrowsError(try allowance.configure(policy(limit: limit, target: allowance.currentPolicy.targetSelection), at: now, calendar: calendar)) {
                XCTAssertEqual($0 as? DailyAllowanceError, .invalidDailyLimit)
            }
        }
    }

    func testAvailableDurationsFitRemainingBudgetAndLocalDay() throws {
        let now = date("2026-11-14T23:50:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        allowance.consumedMinutes = 55
        allowance.usageDayStart = calendar.startOfDay(for: now)

        XCTAssertEqual(allowance.availableDurations(at: now, calendar: calendar), [5])
    }

    func testLastGrantRemainsActiveAtZeroBalanceAndCannotBeStartedAgain() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 5, at: now)
        let grant = try allowance.beginGrant(minutes: 5, id: UUID(), at: now, calendar: calendar)

        XCTAssertEqual(allowance.remainingMinutes(at: now, calendar: calendar), 0)
        XCTAssertEqual(allowance.activeGrant(at: now), grant)
        XCTAssertThrowsError(try allowance.beginGrant(minutes: 5, id: UUID(), at: now.addingTimeInterval(60), calendar: calendar)) {
            XCTAssertEqual($0 as? DailyAllowanceError, .grantAlreadyActive)
        }
        XCTAssertEqual(allowance.consumedMinutes, 5)
        XCTAssertEqual(allowance.activeGrant(at: now), grant)
        XCTAssertNil(allowance.activeGrant(at: grant.expiresAt))
        XCTAssertEqual(allowance.consumedMinutes, 5, "Natural expiry does not return the reserved minutes")
    }

    func testPaidCustomUnlockDoesNotConsumeDailyAllowanceAndExpiresAtChosenTime() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        allowance.consumedMinutes = 25
        allowance.usageDayStart = calendar.startOfDay(for: now)

        let grant = try allowance.beginPaidGrant(minutes: 47, transactionID: 987, at: now, calendar: calendar)

        XCTAssertEqual(grant.expiresAt, now.addingTimeInterval(47 * 60))
        XCTAssertEqual(grant.purchaseTransactionID, 987)
        XCTAssertEqual(allowance.remainingMinutes(at: now, calendar: calendar), 35)
        XCTAssertEqual(allowance.activeGrant(at: now), grant)
        XCTAssertEqual(allowance.lastPaidPurchaseTransactionID, 987)
    }

    func testPaidCustomUnlockMustExceedFreeGrantAndMayCrossMidnight() throws {
        let now = date("2026-11-14T23:40:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)

        XCTAssertThrowsError(try allowance.beginPaidGrant(minutes: 15, transactionID: 15, at: now, calendar: calendar)) {
            XCTAssertEqual($0 as? DailyAllowanceError, .invalidPaidDuration)
        }
        let grant = try allowance.beginPaidGrant(minutes: 120, transactionID: 120, at: now, calendar: calendar)
        XCTAssertEqual(grant.expiresAt, date("2026-11-15T01:40:00Z"))
        XCTAssertEqual(allowance.activeGrant(at: date("2026-11-15T00:00:00Z")), grant)
        XCTAssertEqual(allowance.remainingMinutes(at: now, calendar: calendar), 60)
    }

    func testPaidCustomUnlockHasNoSixtyMinuteCap() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)

        let grant = try allowance.beginPaidGrant(minutes: 120, transactionID: 120, at: now, calendar: calendar)
        XCTAssertEqual(grant.expiresAt, now.addingTimeInterval(120 * 60))
        XCTAssertEqual(allowance.remainingMinutes(at: now, calendar: calendar), 60)
    }

    func testEndingGrantEarlyRefundsOnlyWholeUnusedMinutes() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        let grant = try allowance.beginGrant(minutes: 10, id: UUID(), at: now, calendar: calendar)

        try allowance.endGrant(id: grant.id, at: now.addingTimeInterval(140), calendar: calendar)

        XCTAssertEqual(allowance.consumedMinutes, 3)
        XCTAssertNil(allowance.activeGrant(at: now.addingTimeInterval(140)))
        XCTAssertEqual(allowance.remainingMinutes(at: now.addingTimeInterval(140), calendar: calendar), 57)
    }

    func testEndingGrantWithLessThanOneWholeMinuteRemainingReturnsNothing() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        let grant = try allowance.beginGrant(minutes: 5, id: UUID(), at: now, calendar: calendar)

        try allowance.endGrant(id: grant.id, at: now.addingTimeInterval(299), calendar: calendar)

        XCTAssertEqual(allowance.consumedMinutes, 5)
        XCTAssertEqual(allowance.remainingMinutes(at: now.addingTimeInterval(299), calendar: calendar), 55)
    }

    func testOldGrantIDCannotEndAnotherGrant() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        let grant = try allowance.beginGrant(minutes: 5, id: UUID(), at: now, calendar: calendar)

        XCTAssertThrowsError(try allowance.endGrant(id: UUID(), at: now.addingTimeInterval(60), calendar: calendar)) {
            XCTAssertEqual($0 as? DailyAllowanceError, .invalidGrant)
        }
        XCTAssertEqual(allowance.grant, grant)
        XCTAssertEqual(allowance.consumedMinutes, 5)
    }

    func testEndingPaidGrantDoesNotReturnPurchasedTimeAsFreeAllowance() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        let grant = try allowance.beginPaidGrant(minutes: 45, transactionID: 123, at: now, calendar: calendar)

        try allowance.endGrant(id: grant.id, at: now.addingTimeInterval(600), calendar: calendar)

        XCTAssertEqual(allowance.consumedMinutes, 0)
        XCTAssertEqual(allowance.remainingMinutes(at: now.addingTimeInterval(600), calendar: calendar), 60)
        XCTAssertNil(allowance.activeGrant(at: now.addingTimeInterval(600)))
    }

    func testUsageCounterRollsOverAtLocalDayBoundary() throws {
        let today = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: today)
        _ = try allowance.beginGrant(minutes: 15, id: UUID(), at: today, calendar: calendar)

        let tomorrow = date("2026-11-15T00:00:00Z")
        XCTAssertEqual(allowance.remainingMinutes(at: tomorrow, calendar: calendar), 60)
        XCTAssertEqual(allowance.availableDurations(at: tomorrow, calendar: calendar), [5, 10, 15])
    }

    func testAppliedPendingPolicyStaysCurrentWhenFollowingChangeIsScheduled() throws {
        let monday = date("2026-11-16T10:00:00Z")
        let initial = policy(limit: 60, target: LockTargetSelectionRef(displayName: "A", tokenData: Data([1])))
        var allowance = DailyAllowanceState(currentPolicy: initial)
        let tuesdayPolicy = policy(limit: 30, target: LockTargetSelectionRef(displayName: "B", tokenData: Data([2])))
        try allowance.configure(tuesdayPolicy, at: monday, calendar: calendar)

        let tuesday = date("2026-11-17T10:00:00Z")
        XCTAssertEqual(allowance.policy(at: tuesday, calendar: calendar), tuesdayPolicy)

        let wednesdayPolicy = policy(limit: 15, target: LockTargetSelectionRef(displayName: "C", tokenData: Data([3])))
        try allowance.configure(wednesdayPolicy, at: tuesday, calendar: calendar)

        XCTAssertEqual(allowance.policy(at: tuesday, calendar: calendar), tuesdayPolicy)
        XCTAssertEqual(allowance.policy(at: date("2026-11-18T10:00:00Z"), calendar: calendar), wednesdayPolicy)
    }

    func testAllowanceExpiryMonitorStartsAtDeadlineAndLastsAtLeastFifteenMinutes() throws {
        let now = date("2026-11-14T12:00:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        let grant = try allowance.beginGrant(minutes: 5, id: UUID(), at: now, calendar: calendar)
        let schedule = MonitoringSchedule.allowanceExpiry(for: grant, calendar: calendar)

        XCTAssertEqual(schedule.name, grant.monitoringName)
        XCTAssertEqual(calendar.date(from: schedule.start), grant.expiresAt)
        XCTAssertGreaterThanOrEqual(calendar.date(from: schedule.end)!.timeIntervalSince(grant.expiresAt), 15 * 60)
        XCTAssertFalse(schedule.repeats)
    }

    func testPaidAllowanceExpiryMonitorStartsOnFollowingDay() throws {
        let now = date("2026-11-14T23:40:00Z")
        var allowance = configuredAllowance(limit: 60, at: now)
        let grant = try allowance.beginPaidGrant(minutes: 120, transactionID: 120, at: now, calendar: calendar)
        let schedule = MonitoringSchedule.allowanceExpiry(for: grant, calendar: calendar)

        XCTAssertEqual(calendar.date(from: schedule.start), date("2026-11-15T01:40:00Z"))
        XCTAssertEqual(calendar.date(from: schedule.end), date("2026-11-15T01:55:00Z"))
        XCTAssertFalse(schedule.repeats)
    }

    func testAllowanceShieldCoexistsWithRegularLockAndReturnsAfterGrantExpires() throws {
        let now = date("2026-11-14T12:00:00Z")
        let target = LockTargetSelectionRef(displayName: "Social", tokenData: Data([1]))
        var allowance = configuredAllowance(limit: 60, at: now, target: target)
        let grant = try allowance.beginGrant(minutes: 5, id: UUID(), at: now, calendar: calendar)
        var state = LockState(targetSelections: [target], dailyAllowance: allowance)
        let regular = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 1800,
            targetSelectionID: target.id)
        state.rules = [regular]

        XCTAssertFalse(try state.shieldSlotDecisions(at: now).contains { $0.storeName == DailyAllowanceState.shieldStoreName })
        XCTAssertTrue(try state.shieldSlotDecisions(at: now).contains { $0.storeName == regular.shieldStoreName(forOccurrenceStartingAt: regular.single!.startsAt) })

        state.dailyAllowance.grant = grant
        XCTAssertTrue(try state.shieldSlotDecisions(at: grant.expiresAt).contains { $0.storeName == DailyAllowanceState.shieldStoreName })
        XCTAssertTrue(try state.shieldSlotDecisions(at: grant.expiresAt).contains { $0.storeName == regular.shieldStoreName(forOccurrenceStartingAt: regular.single!.startsAt) })
    }

    func testNormalLockBlocksAllowanceOnlyWhenItCoversTheSameTarget() {
        let now = date("2026-11-14T12:00:00Z")
        let dailyTarget = LockTargetSelectionRef(displayName: "Social", tokenData: Data([1]))
        let otherTarget = LockTargetSelectionRef(displayName: "Work", tokenData: Data([2]))
        let allowance = configuredAllowance(limit: 60, at: now, target: dailyTarget)
        let sameTargetRule = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 1800,
            targetSelectionID: dailyTarget.id)
        let otherTargetRule = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-60), duration: 1800,
            targetSelectionID: otherTarget.id)
        let blockedState = LockState(targetSelections: [dailyTarget], rules: [sameTargetRule], dailyAllowance: allowance)
        let availableState = LockState(targetSelections: [dailyTarget, otherTarget], rules: [otherTargetRule], dailyAllowance: allowance)

        XCTAssertNotNil(blockedState.activeNormalLockBlockingDailyAllowance(at: now))
        XCTAssertNil(availableState.activeNormalLockBlockingDailyAllowance(at: now))
    }

    func testAllowanceRunsEveryDayEvenWhenLegacyPolicyStoredWeekdays() throws {
        let now = date("2026-11-14T12:00:00Z")
        let target = LockTargetSelectionRef(displayName: "Social", tokenData: Data([1]))
        let policy = DailyAllowancePolicy(isEnabled: true, targetSelection: target, dailyLimitMinutes: 60)
        var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(policy)) as? [String: Any])
        encoded["weekdays"] = ["monday"]
        let legacyData = try JSONSerialization.data(withJSONObject: encoded)
        let decoded = try JSONDecoder().decode(DailyAllowancePolicy.self, from: legacyData)
        var state = LockState(dailyAllowance: DailyAllowanceState(currentPolicy: decoded))
        XCTAssertEqual(state.dailyAllowanceAccessState(at: now), .available)
        let savedAgain = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        XCTAssertNil(savedAgain["weekdays"])

        state.dailyAllowance.consumedMinutes = 60
        state.dailyAllowance.usageDayStart = Calendar.current.startOfDay(for: now)
        XCTAssertEqual(state.dailyAllowanceAccessState(at: now), .exhausted)

        state.dailyAllowance.consumedMinutes = 55
        let grant = try state.dailyAllowance.beginGrant(minutes: 5, id: UUID(), at: now, calendar: calendar)
        XCTAssertEqual(state.dailyAllowanceAccessState(at: now), .temporarilyUnlocked(grant))
    }

    func testDailyAllowanceStopsAndResumesTomorrowWithoutChangingTodayUsage() throws {
        let now = date("2026-11-14T12:00:00Z")
        let original = configuredAllowance(limit: 60, at: now)
        var allowance = original
        allowance.consumedMinutes = 20

        try allowance.configure(DailyAllowancePolicy(isEnabled: false, targetSelection: original.currentPolicy.targetSelection, dailyLimitMinutes: 60), at: now, calendar: calendar)

        XCTAssertTrue(allowance.policy(at: now, calendar: calendar).isEnabled)
        XCTAssertEqual(allowance.consumedMinutes, 20)
        let tomorrow = date("2026-11-15T00:00:00Z")
        XCTAssertFalse(allowance.policy(at: tomorrow, calendar: calendar).isEnabled)

        try allowance.configure(DailyAllowancePolicy(isEnabled: true, targetSelection: original.currentPolicy.targetSelection, dailyLimitMinutes: 60), at: tomorrow, calendar: calendar)

        XCTAssertFalse(allowance.policy(at: tomorrow, calendar: calendar).isEnabled)
        XCTAssertTrue(allowance.policy(at: date("2026-11-16T00:00:00Z"), calendar: calendar).isEnabled)
        XCTAssertEqual(allowance.consumedMinutes, 20)
    }

    func testAllowanceClosesRequestsWhenFewerThanFiveMinutesRemainInDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let now = dayEnd.addingTimeInterval(-4 * 60)
        let allowance = configuredAllowance(limit: 60, at: now)
        let state = LockState(dailyAllowance: allowance)

        XCTAssertEqual(state.dailyAllowanceAccessState(at: now), .dayBoundaryTooClose)
        XCTAssertTrue(allowance.availableDurations(at: now).isEmpty)
        XCTAssertEqual(allowance.remainingMinutes(at: now, calendar: calendar), 60)
    }

    private func configuredAllowance(limit: Int, at now: Date, target: LockTargetSelectionRef? = nil) -> DailyAllowanceState {
        DailyAllowanceState(currentPolicy: policy(limit: limit, target: target ?? LockTargetSelectionRef(displayName: "Social", tokenData: Data([1]))),
            usageDayStart: calendar.startOfDay(for: now))
    }

    private func policy(limit: Int, target: LockTargetSelectionRef?) -> DailyAllowancePolicy {
        DailyAllowancePolicy(isEnabled: true, targetSelection: target, dailyLimitMinutes: limit)
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
}
