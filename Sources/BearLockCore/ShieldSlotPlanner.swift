import Foundation

public enum LockEvaluationError: Error {
    case missingSelection(UUID)
}

/// One independently managed shield store. A stale callback can only change its own slot.
public struct ShieldSlotDecision: Equatable, Sendable {
    public var storeName: String
    public var selection: LockTargetSelectionRef

    public init(storeName: String, selection: LockTargetSelectionRef) {
        self.storeName = storeName
        self.selection = selection
    }
}

public extension LockState {
    func dailyAllowanceAccessState(at date: Date) -> DailyAllowanceAccessState {
        let policy = dailyAllowance.policy(at: date)
        guard dailyAllowance.isConfigured else { return .notConfigured }
        guard policy.isEnabled else { return .disabled }
        if activeNormalLockBlockingDailyAllowance(at: date) != nil { return .blockedByNormalLock }
        if let grant = dailyAllowance.activeGrant(at: date) { return .temporarilyUnlocked(grant) }
        if dailyAllowance.remainingMinutes(at: date) == 0 { return .exhausted }
        if dailyAllowance.isNearLocalDayBoundary(at: date) { return .dayBoundaryTooClose }
        return .available
    }

    func activeNormalLockBlockingDailyAllowance(at date: Date) -> ActiveLock? {
        let policy = dailyAllowance.policy(at: date)
        guard policy.isEnabled,
              let targetData = policy.targetSelection?.tokenData
        else { return nil }

        return activeLocks(at: date).first { lock in
            guard let rule = rules.last(where: { $0.id == lock.id }),
                  let selection = targetSelections.last(where: { $0.id == rule.targetSelectionID })
            else { return false }
            return selection.tokenData == targetData
        }
    }

    /// Stores that may still enforce now or in the future. Expired and disabled stores become
    /// orphans and are cleared during the next reconciliation.
    func shieldStoreNames(at date: Date) -> Set<String> {
        Set(rules.filter { rule in
            guard rule.isScheduled(at: date) else { return false }
            return rule.recurrence != nil || (rule.single?.endsAt ?? .distantPast) > date
        }.flatMap(\.shieldStoreNames)).union([DailyAllowanceState.shieldStoreName])
    }

    /// Active stores are derived only from persisted rules and the current time. The callback
    /// type is deliberately absent, making duplicate, delayed, and reversed callbacks idempotent.
    func shieldSlotDecisions(at date: Date) throws -> [ShieldSlotDecision] {
        let regular: [ShieldSlotDecision] = try rules.compactMap { rule -> ShieldSlotDecision? in
            guard rule.isScheduled(at: date),
                  let occurrence = rule.occurrence(containing: date),
                  date < wakeState.effectiveEnd(of: occurrence)
            else { return nil }
            guard let selection = targetSelections.last(where: { $0.id == rule.targetSelectionID }) else {
                throw LockEvaluationError.missingSelection(rule.targetSelectionID)
            }
            return ShieldSlotDecision(
                storeName: rule.shieldStoreName(forOccurrenceStartingAt: occurrence.startedAt),
                selection: selection
            )
        }
        if let selection = dailyAllowance.shieldTarget(at: date) {
            return regular + [ShieldSlotDecision(storeName: DailyAllowanceState.shieldStoreName, selection: selection)]
        }
        return regular
    }

    func shieldSlotDecision(named storeName: String, at date: Date) throws -> ShieldSlotDecision? {
        try shieldSlotDecisions(at: date).first { $0.storeName == storeName }
    }
}

public extension LockRule {
    var shieldStoreNames: [String] {
        let base = "bearlock.\(id.uuidString)"
        guard let recurrence else { return [base] }
        return recurrence.weekdays.sorted().map { "\(base).\($0.rawValue)" }
    }

    func shieldStoreName(forOccurrenceStartingAt start: Date) -> String {
        let base = "bearlock.\(id.uuidString)"
        guard let recurrence else { return base }
        var calendar = Calendar(identifier: recurrence.calendarIdentifier)
        calendar.timeZone = TimeZone(identifier: recurrence.timeZoneIdentifier) ?? .current
        return "\(base).\(calendar.component(.weekday, from: start))"
    }
}
