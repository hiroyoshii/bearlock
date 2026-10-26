import Foundation

public struct LockPlanner: Sendable {
    public init() {}

    public func makeRule(
        from request: LockCreationRequest,
        now: Date,
        existingState: LockState
    ) throws -> LockRule {
        var rule: LockRule

        switch request {
        case let .now(duration, targetSelectionID):
            try validateDuration(duration)
            rule = LockRule(
                kind: .immediate,
                startsAt: now,
                duration: duration,
                targetSelectionID: targetSelectionID
            )

        case let .delayed(delay, duration, targetSelectionID):
            try validateDuration(duration)
            guard delay >= 0 else { throw LockValidationError.startDateInPast }
            rule = LockRule(
                kind: .delayed,
                startsAt: now.addingTimeInterval(delay),
                duration: duration,
                targetSelectionID: targetSelectionID
            )

        case let .fixed(startsAt, duration, targetSelectionID):
            try validateDuration(duration)
            guard startsAt >= now else { throw LockValidationError.startDateInPast }
            rule = LockRule(
                kind: .fixedDateTime,
                startsAt: startsAt,
                duration: duration,
                targetSelectionID: targetSelectionID
            )

        case let .recurring(recurrence, targetSelectionID):
            try validateDuration(recurrence.duration)
            guard !recurrence.weekdays.isEmpty else { throw LockValidationError.emptyWeekdays }
            rule = LockRule(
                recurrence: recurrence,
                targetSelectionID: targetSelectionID
            )
        }

        rule = rule.normalizedForMonitoring()

        if overlaps(rule: rule, existingState: existingState, now: now) {
            throw LockValidationError.overlappingLock
        }

        return rule
    }

    public func validateScheduledReplacement(
        _ replacement: LockRule,
        replacing original: LockRule,
        now: Date,
        existingState: LockState
    ) throws -> LockRule {
        guard let originalSingle = original.single, originalSingle.startsAt > now else {
            throw LockValidationError.ruleAlreadyStarted
        }
        guard let replacementSingle = replacement.single, replacementSingle.startsAt > now else {
            throw LockValidationError.startDateInPast
        }
        try validateDuration(replacementSingle.duration)

        var normalized = replacement
        normalized.id = original.id
        normalized.status = .scheduled
        normalized.scheduledDeletionAt = nil

        normalized = normalized.normalizedForMonitoring()

        if overlaps(rule: normalized, existingState: existingState, now: now) {
            throw LockValidationError.overlappingLock
        }

        return normalized
    }

    public func validateRecurringReplacement(
        _ replacement: LockRule,
        replacing original: LockRule,
        now: Date,
        existingState: LockState,
        enabled: Bool? = nil
    ) throws -> LockRule {
        try existingState.validateEditable(original, at: now)
        guard original.kind == .recurring,
              let recurrence = replacement.recurrence
        else {
            throw LockValidationError.notRecurringRule
        }
        guard !recurrence.weekdays.isEmpty else { throw LockValidationError.emptyWeekdays }
        try validateDuration(recurrence.duration)

        var normalized = replacement
        normalized.id = original.id
        normalized.status = (enabled ?? (original.status != .disabled)) ? .scheduled : .disabled
        normalized.scheduledDeletionAt = nil

        normalized = normalized.normalizedForMonitoring()

        if normalized.status == .scheduled && overlaps(rule: normalized, existingState: existingState, now: now) {
            throw LockValidationError.overlappingLock
        }

        return normalized
    }

    private func validateDuration(_ duration: TimeInterval) throws {
        guard duration > 0 else { throw LockValidationError.nonPositiveDuration }
    }

    func overlaps(
        rule: LockRule,
        existingState: LockState,
        now: Date
    ) -> Bool {
        guard rule.isScheduled(at: now) else { return false }
        for other in existingState.rules where other.id != rule.id && other.isScheduled(at: now) {
            if let single = rule.single ?? other.single {
                if intersects(rule, other, state: existingState, from: max(now, single.startsAt), until: single.endsAt) { return true }
            } else if recurringOverlap(rule, other, state: existingState, now: now) {
                return true
            }
        }
        return false
    }

    private func recurringOverlap(_ rule: LockRule, _ other: LockRule, state: LockState, now: Date) -> Bool {
        let a = rule.recurrence!, b = other.recurrence!
        if a.timeZoneIdentifier == b.timeZoneIdentifier && rule.scheduledDeletionAt == nil && other.scheduledDeletionAt == nil {
            // Infinite weekly schedules eventually repeat beyond any occurrence-specific wake.
            for first in a.weekdays {
                let x = ((first.rawValue + 5) % 7) * 1440 + a.startsAt.minutesFromMidnight
                for second in b.weekdays {
                    let y = ((second.rawValue + 5) % 7) * 1440 + b.startsAt.minutesFromMidnight
                    for shift in [-10080, 0, 10080] {
                        if x < y + shift + Int(b.duration / 60) && y + shift < x + Int(a.duration / 60) { return true }
                    }
                }
            }
            return false
        }
        // Between offset/wake/deletion boundaries the UTC weekly pattern is constant.
        // Check both edges of each segment for occurrences crossing a DST transition.
        // Gregorian future timezone rules repeat over a 400-year calendar cycle.
        let day: TimeInterval = 86_400
        let window = 8 * day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var limit = calendar.date(byAdding: .year, value: 400, to: now)!
        for deletion in [rule.scheduledDeletionAt, other.scheduledDeletionAt].compactMap({ $0 }) {
            limit = min(limit, deletion.addingTimeInterval(2 * day))
        }
        let zones = [a, b].compactMap { TimeZone(identifier: $0.timeZoneIdentifier) }
        let wakeBoundaries = state.wakeState.requests.filter { $0.ruleID == rule.id || $0.ruleID == other.id }
            .flatMap { [$0.occurrenceStartedAt, $0.wakesAt] }
        var cursor = now
        while cursor < limit {
            let transitions = zones.compactMap { $0.nextDaylightSavingTimeTransition(after: cursor) }
            let next = (transitions + wakeBoundaries.filter { $0 > cursor } + [limit]).min()!
            if intersects(rule, other, state: state, from: cursor, until: min(next, cursor.addingTimeInterval(window))) { return true }
            if next.timeIntervalSince(cursor) > window && intersects(rule, other, state: state, from: next.addingTimeInterval(-window), until: next) { return true }
            cursor = next
        }
        return false
    }

    private func intersects(_ rule: LockRule, _ other: LockRule, state: LockState, from: Date, until: Date) -> Bool {
        guard from < until else { return false }
        let left = occupiedIntervals(rule, state: state, from: from, until: until)
        let right = occupiedIntervals(other, state: state, from: from, until: until)
        return left.contains { a in right.contains { b in a.start < b.end && b.start < a.end } }
    }

    private func occupiedIntervals(_ rule: LockRule, state: LockState, from: Date, until: Date) -> [DateInterval] {
        var cursor = from
        var result: [DateInterval] = []
        while let interval = rule.nextInterval(after: cursor), interval.start < until {
            let lock = ActiveLock(id: rule.id, startedAt: interval.start, endsAt: interval.end,
                                  targetSelectionID: rule.targetSelectionID)
            let start = max(from, interval.start)
            let end = min(until, state.wakeState.effectiveEnd(of: lock), rule.scheduledDeletionAt ?? until)
            if start < end { result.append(DateInterval(start: start, end: end)) }
            guard interval.end > cursor else { break }
            cursor = interval.end
        }
        return result
    }
}
