import Foundation

public extension LockRule {
    /// Immediate starts may round down by less than a second; future starts round up.
    /// End dates always round up so the promised duration is never shortened.
    func normalizedForMonitoring() -> LockRule {
        var rule = self
        let end = ceil(endsAt.timeIntervalSince1970)
        let start = kind == .immediate ? floor(startsAt.timeIntervalSince1970) : ceil(startsAt.timeIntervalSince1970)
        rule.startsAt = Date(timeIntervalSince1970: start)
        rule.duration = max(1, end - start)
        return rule
    }

    func monitoringComponents(calendar: Calendar = .current) -> (start: DateComponents, end: DateComponents) {
        let components: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
        var start = calendar.dateComponents(components, from: startsAt)
        var end = calendar.dateComponents(components, from: Date(timeIntervalSince1970: ceil(endsAt.timeIntervalSince1970)))
        start.timeZone = calendar.timeZone
        end.timeZone = calendar.timeZone
        return (start, end)
    }

    func occurrence(containing date: Date) -> LockRule? {
        guard kind == .recurring else { return contains(date) ? self : nil }
        guard let interval = recurrence?.nextInterval(after: date),
              interval.start <= date, date < interval.end else { return nil }
        var occurrence = self
        occurrence.startsAt = interval.start
        occurrence.duration = interval.duration
        return occurrence
    }
}

public extension ActiveLock {
    /// Keeps the current occurrence's end independent of edits to its parent rule.
    var completionMonitoringRule: LockRule {
        LockRule(kind: .fixedDateTime, startsAt: startedAt,
                 duration: (scheduledEndsAt ?? endsAt).timeIntervalSince(startedAt),
                 targetSelectionID: targetSelectionID)
    }
}
