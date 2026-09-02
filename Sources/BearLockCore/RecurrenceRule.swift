import Foundation

public struct RecurrenceRule: Codable, Equatable, Sendable {
    public var weekdays: Set<Weekday>
    public var startsAt: TimeOfDay
    public var endsAt: TimeOfDay
    public var calendarIdentifier: Calendar.Identifier
    public var timeZoneIdentifier: String

    public init(
        weekdays: Set<Weekday>,
        startsAt: TimeOfDay,
        endsAt: TimeOfDay,
        calendarIdentifier: Calendar.Identifier = .gregorian,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.weekdays = weekdays
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.calendarIdentifier = calendarIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var duration: TimeInterval {
        let start = startsAt.minutesFromMidnight
        let end = endsAt.minutesFromMidnight
        let minutes = end > start ? end - start : (24 * 60 - start) + end
        return TimeInterval(minutes * 60)
    }

    public func nextInterval(after date: Date) -> DateInterval? {
        guard !weekdays.isEmpty else { return nil }

        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) else {
                continue
            }

            let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day))
            guard weekdays.contains(weekday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = startsAt.hour
            components.minute = startsAt.minute
            components.second = 0

            guard let start = calendar.date(from: components) else { continue }
            let end = start.addingTimeInterval(duration)

            if end > date {
                if start <= date {
                    return DateInterval(start: start, end: end)
                }
                return DateInterval(start: start, end: end)
            }
        }

        return nil
    }
}

public struct TimeOfDay: Codable, Equatable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        precondition((0...23).contains(hour), "hour must be 0...23")
        precondition((0...59).contains(minute), "minute must be 0...59")
        self.hour = hour
        self.minute = minute
    }

    public var minutesFromMidnight: Int {
        hour * 60 + minute
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }
}

public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public init(calendarWeekday: Int) {
        self = Weekday(rawValue: calendarWeekday) ?? .sunday
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension Weekday {
    func shortName(locale: Locale = .current) -> String {
        if locale.language.languageCode == .japanese {
            switch self {
            case .sunday: return "日"
            case .monday: return "月"
            case .tuesday: return "火"
            case .wednesday: return "水"
            case .thursday: return "木"
            case .friday: return "金"
            case .saturday: return "土"
            }
        }

        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }
}
