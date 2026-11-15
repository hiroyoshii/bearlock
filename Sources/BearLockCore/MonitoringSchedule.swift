import Foundation

public struct MonitoringSchedule: Equatable, Sendable {
    public static let maximumOwnedStoreCount = 48
    public var name: String
    public var start: DateComponents
    public var end: DateComponents
    public var repeats: Bool

    public init(name: String, start: DateComponents, end: DateComponents, repeats: Bool) {
        self.name = name; self.start = start; self.end = end; self.repeats = repeats
    }

    public static func desired(for rules: [LockRule], at now: Date) -> [Self] {
        rules.filter { $0.isScheduled(at: now) }.flatMap { rule -> [Self] in
            let name = "bearlock.\(rule.id.uuidString)"
            if let recurrence = rule.recurrence {
                var calendar = Calendar(identifier: recurrence.calendarIdentifier)
                calendar.timeZone = TimeZone(identifier: recurrence.timeZoneIdentifier) ?? .current
                return recurrence.weekdays.sorted().map { day in
                    let overnight = recurrence.endsAt <= recurrence.startsAt
                    let endDay = overnight ? day.rawValue % 7 + 1 : day.rawValue
                    let start = DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                        hour: recurrence.startsAt.hour, minute: recurrence.startsAt.minute, second: 0, weekday: day.rawValue)
                    let end = DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                        hour: recurrence.endsAt.hour, minute: recurrence.endsAt.minute, second: 0, weekday: endDay)
                    return Self(name: "\(name).\(day.rawValue)", start: start, end: end, repeats: true)
                }
            }
            guard let single = rule.single, single.endsAt > now else { return [] }
            let components = single.monitoringComponents()
            return [Self(name: name, start: components.start, end: components.end, repeats: false)]
        }
    }

    public static func desired(for state: LockState, at now: Date) -> [Self] {
        let daily = state.dailyAllowance.requiresBoundaryMonitoring(at: now)
            ? [dailyAllowanceBoundary(calendar: .current)] : []
        let grant = state.dailyAllowance.grant.flatMap { $0.expiresAt > now ? allowanceExpiry(for: $0, calendar: .current) : nil }
        return desired(for: state.rules, at: now) + daily + [grant].compactMap { $0 } + state.wakeState.requests.compactMap { request in
            guard request.source == .delayed, request.wakesAt > now,
                  let rule = state.rules.first(where: { $0.id == request.ruleID }),
                  let interval = rule.nextInterval(after: request.occurrenceStartedAt),
                  interval.start == request.occurrenceStartedAt,
                  request.wakesAt < interval.end
            else { return nil }
            let calendar = Calendar.current
            let components: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
            var start = calendar.dateComponents(components, from: request.wakesAt)
            var end = calendar.dateComponents(components, from: request.wakesAt.addingTimeInterval(15 * 60))
            start.timeZone = calendar.timeZone
            end.timeZone = calendar.timeZone
            return Self(name: "bearlock.wake.\(request.id.uuidString)", start: start, end: end, repeats: false)
        }
    }

    public static func allowanceExpiry(for grant: DailyAllowanceGrant, calendar: Calendar = .current) -> Self {
        var start = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: grant.expiresAt)
        let endDate = grant.expiresAt.addingTimeInterval(15 * 60)
        var end = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: endDate)
        start.timeZone = calendar.timeZone
        end.timeZone = calendar.timeZone
        return Self(name: grant.monitoringName, start: start, end: end, repeats: false)
    }

    public static func dailyAllowanceBoundary(calendar: Calendar = .current) -> Self {
        let zone = calendar.timeZone
        let start = DateComponents(timeZone: zone, hour: 0, minute: 0, second: 0)
        let end = DateComponents(timeZone: zone, hour: 23, minute: 59, second: 59)
        return Self(name: "bearlock.daily.boundary", start: start, end: end, repeats: true)
    }

    public static func validateCapacity(for rules: [LockRule], at now: Date) throws {
        guard desired(for: rules, at: now).count <= maximumOwnedStoreCount else {
            throw LockValidationError.monitoringCapacityExceeded
        }
    }

    public static func validateCapacity(for state: LockState, at now: Date) throws {
        guard desired(for: state, at: now).count <= maximumOwnedStoreCount else {
            throw LockValidationError.monitoringCapacityExceeded
        }
    }

    /// Retry derives the missing work from the saved rules and OS registrations.
    /// Attempt independent registrations even if one fails; surface the first error.
    public static func synchronize(
        desired: [Self], existing: [Self],
        start: (Self) throws -> Void, stop: (String) throws -> Void
    ) throws {
        var failure: Error?
        let names = Set(desired.map(\.name))
        for old in existing where old.name.hasPrefix("bearlock.") && !names.contains(old.name) {
            do { try stop(old.name) } catch { failure = failure ?? error }
        }
        for schedule in desired where !existing.contains(schedule) {
            do { try start(schedule) } catch { failure = failure ?? error }
        }
        if let failure { throw failure }
    }
}
