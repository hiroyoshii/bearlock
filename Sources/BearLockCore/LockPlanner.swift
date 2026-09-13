import Foundation

public struct LockPlanner: Sendable {
    public init() {}

    public func makeRule(
        from request: LockCreationRequest,
        now: Date,
        existingRules: [LockRule]
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

        if overlaps(rule: rule, existingRules: existingRules, now: now) {
            throw LockValidationError.overlappingLock
        }

        return rule
    }

    public func validateScheduledReplacement(
        _ replacement: LockRule,
        replacing original: LockRule,
        now: Date,
        existingRules: [LockRule]
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

        normalized = normalized.normalizedForMonitoring()

        if overlaps(rule: normalized, existingRules: existingRules, now: now) {
            throw LockValidationError.overlappingLock
        }

        return normalized
    }

    public func validateRecurringReplacement(
        _ replacement: LockRule,
        replacing original: LockRule,
        now: Date,
        existingRules: [LockRule],
        enabled: Bool? = nil
    ) throws -> LockRule {
        try original.validateEditable(at: now)
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

        normalized = normalized.normalizedForMonitoring()

        if normalized.status == .scheduled && overlaps(rule: normalized, existingRules: existingRules, now: now) {
            throw LockValidationError.overlappingLock
        }

        return normalized
    }

    private func validateDuration(_ duration: TimeInterval) throws {
        guard duration > 0 else { throw LockValidationError.nonPositiveDuration }
    }

    private func overlaps(
        rule: LockRule,
        existingRules: [LockRule],
        now: Date
    ) -> Bool {
        existingRules.filter { $0.id != rule.id && $0.status == .scheduled && ($0.single == nil || $0.single!.endsAt > now) }.contains { other in
            // Preserve the existing policy allowing multiple repeating rules.
            // Enforcement takes the union of all currently active target sets.
            if !rule.isOneShot && !other.isOneShot { return false }
            let fixed = (rule.single ?? other.single)!
            let candidate = rule.isOneShot ? other : rule
            guard let interval = candidate.nextInterval(after: fixed.startsAt) else { return false }
            return fixed.startsAt < interval.end && interval.start < fixed.endsAt
        }
    }
}
