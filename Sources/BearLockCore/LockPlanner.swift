import Foundation

public struct LockPlanner: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func makeRule(
        from request: LockCreationRequest,
        now: Date,
        existingRules: [LockRule],
        activeLock: ActiveLock?
    ) throws -> LockRule {
        let rule: LockRule

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
            guard let interval = recurrence.nextInterval(after: now) else {
                throw LockValidationError.emptyWeekdays
            }
            rule = LockRule(
                kind: .recurring,
                startsAt: interval.start,
                duration: interval.duration,
                recurrence: recurrence,
                targetSelectionID: targetSelectionID
            )
        }

        if overlaps(rule: rule, existingRules: existingRules, activeLock: activeLock, now: now) {
            throw LockValidationError.overlappingLock
        }

        return rule
    }

    public func activeLock(from rule: LockRule, intervalStart: Date? = nil) -> ActiveLock {
        let startedAt = intervalStart ?? rule.startsAt
        return ActiveLock(
            sourceRuleID: rule.id,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(rule.duration),
            targetSelectionID: rule.targetSelectionID
        )
    }

    public func validateScheduledReplacement(
        _ replacement: LockRule,
        replacing original: LockRule,
        now: Date,
        existingRules: [LockRule],
        activeLock: ActiveLock?
    ) throws -> LockRule {
        guard original.startsAt > now else {
            throw LockValidationError.ruleAlreadyStarted
        }
        guard replacement.startsAt > now else {
            throw LockValidationError.startDateInPast
        }
        try validateDuration(replacement.duration)

        if let activeLock, activeLock.sourceRuleID == original.id, activeLock.isActive(at: now) {
            throw LockValidationError.activeLockIsImmutable
        }

        var normalized = replacement
        normalized.id = original.id
        normalized.status = .scheduled

        if overlaps(rule: normalized, existingRules: existingRules, activeLock: activeLock, now: now) {
            throw LockValidationError.overlappingLock
        }

        return normalized
    }

    public func validateRecurringReplacement(
        _ replacement: LockRule,
        replacing original: LockRule,
        now: Date,
        existingRules: [LockRule],
        activeLock: ActiveLock?
    ) throws -> LockRule {
        guard original.kind == .recurring,
              let recurrence = replacement.recurrence
        else {
            throw LockValidationError.notRecurringRule
        }
        guard !recurrence.weekdays.isEmpty else { throw LockValidationError.emptyWeekdays }
        try validateDuration(recurrence.duration)

        guard let interval = recurrence.nextInterval(after: now) else {
            throw LockValidationError.emptyWeekdays
        }

        var normalized = replacement
        normalized.id = original.id
        normalized.kind = .recurring
        normalized.startsAt = interval.start
        normalized.duration = interval.duration
        normalized.status = original.status == .disabled ? .disabled : .scheduled

        if overlaps(rule: normalized, existingRules: existingRules, activeLock: activeLock, now: now) {
            throw LockValidationError.overlappingLock
        }

        return normalized
    }

    public func recurringRule(_ rule: LockRule, enabled: Bool, now: Date) throws -> LockRule {
        guard rule.kind == .recurring,
              let recurrence = rule.recurrence
        else {
            throw LockValidationError.notRecurringRule
        }

        var updated = rule
        updated.status = enabled ? .scheduled : .disabled

        if enabled, let interval = recurrence.nextInterval(after: now) {
            updated.startsAt = interval.start
            updated.duration = interval.duration
        }

        return updated
    }

    public func nextRuleOccurrence(for rule: LockRule, after date: Date) -> LockRule? {
        guard let recurrence = rule.recurrence,
              let interval = recurrence.nextInterval(after: date)
        else {
            return nil
        }

        var next = rule
        next.startsAt = interval.start
        next.duration = interval.duration
        next.status = .scheduled
        return next
    }

    public func scheduledRuleContaining(_ date: Date, in rules: [LockRule]) -> LockRule? {
        rules
            .filter { $0.status == .scheduled && $0.contains(date) }
            .sorted { $0.startsAt < $1.startsAt }
            .first
    }

    private func validateDuration(_ duration: TimeInterval) throws {
        guard duration > 0 else { throw LockValidationError.nonPositiveDuration }
    }

    private func overlaps(
        rule: LockRule,
        existingRules: [LockRule],
        activeLock: ActiveLock?,
        now: Date
    ) -> Bool {
        let interval = DateInterval(start: rule.startsAt, end: rule.endsAt)

        if let activeLock, activeLock.isActive(at: now) {
            let activeInterval = DateInterval(start: activeLock.startedAt, end: activeLock.endsAt)
            if interval.intersects(activeInterval) {
                return true
            }
        }

        return existingRules
            .filter { $0.status == .scheduled }
            .contains { existing in
                guard existing.id != rule.id else { return false }
                if existing.kind == .recurring && rule.kind == .recurring {
                    return false
                }
                return interval.intersects(DateInterval(start: existing.startsAt, end: existing.endsAt))
            }
    }
}
