import Foundation

public extension LockRule {
    func normalizedForMonitoring() -> LockRule {
        guard var single else { return self }
        let start = single.kind == .immediate ? floor(single.startsAt.timeIntervalSince1970) : ceil(single.startsAt.timeIntervalSince1970)
        let end = ceil(max(single.endsAt.timeIntervalSince1970, start + single.duration))
        single.startsAt = Date(timeIntervalSince1970: start)
        single.duration = max(1, end - start)
        var rule = self
        rule.schedule = .single(single)
        return rule
    }

    func validateEditable(at date: Date) throws {
        if status == .scheduled && occurrence(containing: date) != nil {
            throw LockValidationError.activeLockIsImmutable
        }
    }

    func occurrence(containing date: Date) -> ActiveLock? {
        guard let interval = nextInterval(after: date), interval.start <= date, date < interval.end else { return nil }
        return ActiveLock(id: id, startedAt: interval.start, endsAt: interval.end, targetSelectionID: targetSelectionID)
    }
}

public extension SingleLockSchedule {
    func monitoringComponents(calendar: Calendar = .current) -> (start: DateComponents, end: DateComponents) {
        let components: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
        var start = calendar.dateComponents(components, from: startsAt)
        var end = calendar.dateComponents(components, from: Date(timeIntervalSince1970: ceil(endsAt.timeIntervalSince1970)))
        start.timeZone = calendar.timeZone
        end.timeZone = calendar.timeZone
        return (start, end)
    }
}
