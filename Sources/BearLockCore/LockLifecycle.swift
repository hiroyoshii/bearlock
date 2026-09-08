import Foundation

public enum LockLifecycleEvent: Equatable, Sendable {
    case refresh
    case intervalStarted(ruleID: UUID)
    case intervalEnded(ruleID: UUID)

    var ruleID: UUID? {
        switch self {
        case .refresh: return nil
        case let .intervalStarted(id), let .intervalEnded(id): return id
        }
    }
}

/// Runs synchronously within one cross-process repository transaction. A callback is
/// a reason to reconcile, not proof that a lock expired (stopMonitoring also calls end).
public struct LockLifecycle {
    private let repository: LockRepository

    public init(repository: LockRepository) { self.repository = repository }

    @discardableResult
    public func reconcile(
        event: LockLifecycleEvent,
        at now: Date,
        apply: (ActiveLock, LockTargetSelectionRef?) throws -> Void,
        clear: () -> Void,
        record: (String) -> Void = { _ in }
    ) throws -> LockState {
        try repository.withExclusiveAccess {
            let original = try repository.load()
            var state = original
            var completedActive = false
            record("event=\(event) now=\(now.ISO8601Format()) active=\(state.activeLock?.id.uuidString ?? "none") end=\(state.activeLock?.endsAt.ISO8601Format() ?? "none")")

            if let ruleID = event.ruleID,
               !state.rules.contains(where: { $0.id == ruleID }),
               state.activeLock?.sourceRuleID != ruleID,
               !state.completedLocks.contains(where: { $0.sourceRuleID == ruleID }) {
                record("skip=unknownActivity")
                return state
            }

            if case let .intervalEnded(ruleID) = event,
               let active = state.activeLock, active.sourceRuleID != ruleID {
                record("skip=activityMismatch")
                return state
            }

            if let active = state.activeLock {
                // New locks carry the immutable occurrence deadline. For legacy one-shot
                // locks, their immutable rule repairs deadlines shifted by a late callback.
                let rule = state.rules.first { $0.id == active.sourceRuleID && $0.isOneShot }
                let scheduledEnd = active.scheduledEndsAt ?? rule?.endsAt
                let expired = active.endsAt <= now || (scheduledEnd.map { $0 <= now } ?? false)
                record("scheduledEnd=\(scheduledEnd?.ISO8601Format() ?? "unknown") expired=\(expired)")
                if !expired {
                    if event == .refresh {
                        try apply(active, state.targetSelections.last { $0.id == active.targetSelectionID })
                    }
                    record("keep=unexpiredOccurrence")
                    return state
                }
                completedActive = true
                state.activeLock = nil
                if !state.completedLocks.contains(where: { $0.id == active.id }) {
                    state.completedLocks.append(active)
                }
            }

            for index in state.rules.indices where state.rules[index].isOneShot && state.rules[index].endsAt <= now {
                if state.rules[index].status == .scheduled { state.rules[index].status = .completed }
            }

            // A delayed/duplicate end must not clear another occurrence which is already due.
            // Refresh and callbacks use the same occurrence calculation.
            if let rule = LockPlanner().scheduledRuleContaining(now, in: state.rules) {
                let active = LockPlanner().activeLock(from: rule)
                state.activeLock = active
                try persist(state, replacing: original, record: record)
                try apply(active, state.targetSelections.last { $0.id == active.targetSelectionID })
                record("apply=scheduledOccurrence rule=\(rule.id) end=\(active.endsAt.ISO8601Format())")
                return state
            }

            let knownExpired = completedActive || state.completedLocks.contains { $0.endsAt <= now || ($0.scheduledEndsAt.map { $0 <= now } ?? false) }
                || state.rules.contains { $0.isOneShot && $0.endsAt <= now && (event.ruleID == nil || $0.id == event.ruleID) }
            if knownExpired {
                // Idempotent, and deliberately before history persistence. If saving fails,
                // a later invocation can retry without extending or resurrecting the lock.
                clear()
                record("clear=expiredNoCurrentOccurrence")
            } else {
                record("skip=noExpiryEvidence")
            }
            try persist(state, replacing: original, record: record)
            return state
        }
    }

    private func persist(_ state: LockState, replacing original: LockState, record: (String) -> Void) throws {
        guard state != original else { return }
        do {
            try repository.save(state)
        } catch {
            record("saveFailed=\(error.localizedDescription)")
            throw error
        }
    }
}
