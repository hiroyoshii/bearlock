import XCTest
@testable import BearLockCore

final class MonitoringScheduleTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-10T12:00:00Z")!

    func testRecurringRegistrationUsesWeekdayAndWallTimeWithoutAnExpiredDate() throws {
        let recurrence = RecurrenceRule(weekdays: [.thursday, .saturday], startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "Asia/Tokyo")
        let rule = LockRule(kind: .recurring, startsAt: now.addingTimeInterval(-86400 * 30), duration: 28800,
            recurrence: recurrence, targetSelectionID: UUID())
        let schedules = MonitoringSchedule.desired(for: [rule], at: now)
        XCTAssertEqual(schedules.count, 2)
        XCTAssertEqual(schedules.map(\.start.weekday), [5, 7])
        XCTAssertEqual(schedules.map(\.end.weekday), [6, 1])
        for schedule in schedules {
            XCTAssertTrue(schedule.repeats)
            XCTAssertNil(schedule.start.year)
            XCTAssertNil(schedule.start.month)
            XCTAssertNil(schedule.start.day)
            XCTAssertEqual(schedule.start.hour, 23)
            XCTAssertEqual(schedule.end.hour, 7)
            XCTAssertEqual(schedule.end.timeZone?.identifier, "Asia/Tokyo")
        }
        XCTAssertEqual(MonitoringSchedule.desired(for: [rule], at: now.addingTimeInterval(86400 * 7)), schedules)
    }

    func testDisabledAndExpiredRulesHaveNoMonitorWhileFutureAndActiveOneShotsDo() {
        let active = LockRule(kind: .immediate, startsAt: now.addingTimeInterval(-123), duration: 900, targetSelectionID: UUID())
        var disabled = active; disabled.id = UUID(); disabled.status = .disabled
        var expired = active; expired.id = UUID(); expired.startsAt = now.addingTimeInterval(-900)
        var future = active; future.id = UUID(); future.startsAt = now.addingTimeInterval(61)
        let schedules = MonitoringSchedule.desired(for: [active, disabled, expired, future], at: now)
        XCTAssertEqual(schedules.count, 2)
        XCTAssertEqual(Calendar.current.date(from: schedules[0].end), active.endsAt)
        XCTAssertEqual(Calendar.current.date(from: schedules[1].start), future.startsAt)
        XCTAssertTrue(schedules.allSatisfy { !$0.repeats })
    }

    func testPartialFailureRetainsSuccessfulRegistrationsAndRetryOnlyStartsMissingOne() throws {
        let desired = [descriptor("a"), descriptor("b"), descriptor("c")]
        var registered: [MonitoringSchedule] = []
        var calls: [String] = []
        XCTAssertThrowsError(try MonitoringSchedule.synchronize(desired: desired, existing: [], start: {
            calls.append($0.name)
            if $0.name == "bearlock.b" { throw Failure.unavailable }
            registered.append($0)
        }, stop: { _ in XCTFail("Unexpected stop") }))
        XCTAssertEqual(calls, desired.map(\.name))
        calls = []
        try MonitoringSchedule.synchronize(desired: desired, existing: registered, start: {
            calls.append($0.name); registered.append($0)
        }, stop: { _ in XCTFail("Unexpected stop") })
        XCTAssertEqual(calls, ["bearlock.b"])
        try MonitoringSchedule.synchronize(desired: desired, existing: registered,
            start: { _ in XCTFail("Unchanged monitor restarted") }, stop: { _ in XCTFail("Unexpected stop") })
    }

    func testChangedScheduleReplacesSameNameAndObsoleteOwnedMonitorsStop() throws {
        let old = descriptor("a")
        var changed = old; changed.end.minute = 45
        var unrelated = descriptor("external"); unrelated.name = "another-app"
        var starts: [MonitoringSchedule] = [], stops: [String] = []
        try MonitoringSchedule.synchronize(desired: [changed], existing: [old, descriptor("removed"), unrelated],
            start: { starts.append($0) }, stop: { stops.append($0) })
        XCTAssertEqual(starts, [changed])
        XCTAssertEqual(stops, ["bearlock.removed"])
    }

    func testStopFailureDoesNotSuppressIndependentStarts() {
        var started = false
        XCTAssertThrowsError(try MonitoringSchedule.synchronize(desired: [descriptor("new")], existing: [descriptor("old")],
            start: { _ in started = true }, stop: { _ in throw Failure.unavailable }))
        XCTAssertTrue(started)
    }

    func testDSTKeepsTheConfiguredMorningEndInsteadOfAddingEightHours() throws {
        let recurrence = RecurrenceRule(weekdays: [.saturday], startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0), timeZoneIdentifier: "America/New_York")
        let dates = [("2026-03-08T05:00:00Z", "2026-03-08T11:00:00Z", 7.0),
                     ("2026-11-01T04:00:00Z", "2026-11-01T12:00:00Z", 9.0)]
        for (current, end, hours) in dates {
            let interval = try XCTUnwrap(recurrence.nextInterval(after: ISO8601DateFormatter().date(from: current)!))
            XCTAssertEqual(interval.end, ISO8601DateFormatter().date(from: end))
            XCTAssertEqual(interval.duration, hours * 3600)
        }
    }

    private func descriptor(_ name: String) -> MonitoringSchedule {
        MonitoringSchedule(name: "bearlock.\(name)", start: DateComponents(hour: 10), end: DateComponents(hour: 11), repeats: false)
    }
    private enum Failure: Error { case unavailable }
}
