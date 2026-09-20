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
    /// Stores that may still enforce now or in the future. Expired and disabled stores become
    /// orphans and are cleared during the next reconciliation.
    func shieldStoreNames(at date: Date) -> Set<String> {
        Set(rules.filter { rule in
            guard rule.status == .scheduled else { return false }
            return rule.recurrence != nil || (rule.single?.endsAt ?? .distantPast) > date
        }.flatMap(\.shieldStoreNames))
    }

    /// Active stores are derived only from persisted rules and the current time. The callback
    /// type is deliberately absent, making duplicate, delayed, and reversed callbacks idempotent.
    func shieldSlotDecisions(at date: Date) throws -> [ShieldSlotDecision] {
        try rules.compactMap { rule in
            guard rule.status == .scheduled,
                  let occurrence = rule.occurrence(containing: date),
                  !wakeState.isAwake(occurrence, at: date)
            else { return nil }
            guard let selection = targetSelections.last(where: { $0.id == rule.targetSelectionID }) else {
                throw LockEvaluationError.missingSelection(rule.targetSelectionID)
            }
            return ShieldSlotDecision(
                storeName: rule.shieldStoreName(forOccurrenceStartingAt: occurrence.startedAt),
                selection: selection
            )
        }
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
