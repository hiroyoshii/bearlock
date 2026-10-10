import Foundation

public struct LockState: Codable, Equatable, Sendable {
    public var targetSelections: [LockTargetSelectionRef]
    public var recentLockTargets: [RecentLockTarget]
    public var rules: [LockRule]
    public var selectedTargetID: UUID?
    public var wakeState: WakeState

    public init(
        targetSelections: [LockTargetSelectionRef] = [],
        recentLockTargets: [RecentLockTarget] = [],
        rules: [LockRule] = [],
        selectedTargetID: UUID? = nil,
        wakeState: WakeState = WakeState()
    ) {
        self.targetSelections = targetSelections
        self.recentLockTargets = recentLockTargets
        self.rules = rules
        self.selectedTargetID = selectedTargetID
        self.wakeState = wakeState
    }

    private enum CodingKeys: String, CodingKey {
        case targetSelections, recentLockTargets, rules, selectedTargetID, wakeState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetSelections = try container.decode([LockTargetSelectionRef].self, forKey: .targetSelections)
        recentLockTargets = try container.decode([RecentLockTarget].self, forKey: .recentLockTargets)
        rules = try container.decode([LockRule].self, forKey: .rules)
        selectedTargetID = try container.decodeIfPresent(UUID.self, forKey: .selectedTargetID)
        wakeState = try container.decodeIfPresent(WakeState.self, forKey: .wakeState) ?? WakeState()
    }

    public var selectedTarget: LockTargetSelectionRef? {
        targetSelections.first { $0.id == selectedTargetID }
    }

    public func activeLockForDisplay(at date: Date) -> ActiveLock? {
        activeLocks(at: date).max { $0.endsAt < $1.endsAt }
    }

    public func activeLocks(at date: Date) -> [ActiveLock] {
        rules.filter { $0.isScheduled(at: date) }
            .compactMap { $0.occurrence(containing: date) }
            .filter { date < wakeState.effectiveEnd(of: $0) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    public func displayedRecentLockTargets(limit: Int = 3) -> [RecentLockTarget] {
        guard limit > 0 else { return [] }

        let pinned = recentLockTargets
            .filter(\.isPinned)
            .sorted { ($0.pinnedAt ?? .distantFuture) < ($1.pinnedAt ?? .distantFuture) }
        let unpinned = recentLockTargets
            .filter { !$0.isPinned }
            .sorted { $0.lastUsedAt > $1.lastUsedAt }

        return Array((pinned + unpinned).prefix(limit))
    }
}

public enum RecentLockTargetError: Error, Equatable, Sendable {
    case targetSelectionNotFound
    case recentTargetNotFound
    case pinnedTargetLimitReached
}

public protocol LockRepository: Sendable {
    func load() throws -> LockState
    func save(_ state: LockState) throws
}

public actor LockStore {
    private let repository: LockRepository

    public init(repository: LockRepository) {
        self.repository = repository
    }

    public func snapshot(at now: Date = Date()) throws -> LockState {
        try update { state in
            state.removeRulesDeleted(at: now)
            return state
        }
    }

    /// Serialize the fresh read and OS registration with app mutations.
    public func synchronizeMonitoring(_ synchronize: @Sendable (LockState, Date) throws -> Void) throws {
        let state = try repository.load()
        try synchronize(state, Date())
    }

    @discardableResult
    public func saveTargetSelection(_ selection: LockTargetSelectionRef, now: Date? = nil) throws -> LockTargetSelectionRef {
        try update { state in
            guard state.activeLocks(at: now ?? Date()).isEmpty else {
                throw LockValidationError.activeLockIsImmutable
            }
            var savedSelection = selection
            if let tokenData = selection.tokenData,
               let existing = state.targetSelections.last(where: { $0.tokenData == tokenData }) {
                savedSelection.id = existing.id
            }

            if let index = state.targetSelections.firstIndex(where: { $0.id == savedSelection.id }) {
                state.targetSelections[index] = savedSelection
            } else {
                state.targetSelections.append(savedSelection)
            }
            state.selectedTargetID = savedSelection.id
            return savedSelection
        }
    }

    public func selectTarget(id: UUID, now: Date? = nil) throws {
        try update { state in
            guard state.activeLocks(at: now ?? Date()).isEmpty else {
                throw LockValidationError.activeLockIsImmutable
            }
            guard state.targetSelections.contains(where: { $0.id == id }) else {
                throw RecentLockTargetError.targetSelectionNotFound
            }
            state.selectedTargetID = id
        }
    }

    public func targetSelection(id: UUID) throws -> LockTargetSelectionRef? {
        try repository.load().targetSelections.last { $0.id == id }
    }

    public func recordRecentLockTarget(targetSelectionID: UUID, usedAt: Date) throws {
        try update { state in
            guard let selectedTarget = state.targetSelections.last(where: { $0.id == targetSelectionID }) else {
                throw RecentLockTargetError.targetSelectionNotFound
            }

            let matchingTargetIDs = Set(
                state.targetSelections
                    .filter { target in
                        if target.id == targetSelectionID {
                            return true
                        }
                        guard let tokenData = selectedTarget.tokenData else {
                            return false
                        }
                        return target.tokenData == tokenData
                    }
                    .map(\.id)
            )

            if let index = state.recentLockTargets.firstIndex(where: { matchingTargetIDs.contains($0.targetSelectionID) }) {
                state.recentLockTargets[index].targetSelectionID = targetSelectionID
                state.recentLockTargets[index].lastUsedAt = usedAt
            } else {
                state.recentLockTargets.append(
                    RecentLockTarget(targetSelectionID: targetSelectionID, lastUsedAt: usedAt)
                )
            }

        }
    }

    public func setRecentLockTargetPinned(id: UUID, pinned: Bool, at date: Date) throws {
        try update { state in
            guard let index = state.recentLockTargets.firstIndex(where: { $0.id == id }) else {
                throw RecentLockTargetError.recentTargetNotFound
            }

            if pinned,
               !state.recentLockTargets[index].isPinned,
               state.recentLockTargets.filter(\.isPinned).count >= 3 {
                throw RecentLockTargetError.pinnedTargetLimitReached
            }

            state.recentLockTargets[index].pinnedAt = pinned ? date : nil
        }
    }

    public func deleteRecentLockTarget(id: UUID) throws {
        try update { state in
            guard state.recentLockTargets.contains(where: { $0.id == id }) else {
                throw RecentLockTargetError.recentTargetNotFound
            }

            state.recentLockTargets.removeAll { $0.id == id }
        }
    }

    public func createRule(_ request: LockCreationRequest, now: Date? = nil) throws -> LockRule {
        try update { state in
            let now = now ?? Date()
            let rule = try LockPlanner().makeRule(from: request, now: now, existingState: state)
            state.rules.append(rule)
            try MonitoringSchedule.validateCapacity(for: state.rules, at: now)
            return rule
        }
    }

    public func replaceRule(_ replacement: LockRule, now: Date? = nil) throws {
        try update { state in
            guard let index = state.rules.firstIndex(where: { $0.id == replacement.id }) else {
                throw LockValidationError.ruleNotFound
            }
            let original = state.rules[index]
            let now = now ?? Date()
            try state.validateEditable(original, at: now)
            let planner = LockPlanner()
            state.rules[index] = try original.kind == .recurring
                ? planner.validateRecurringReplacement(replacement, replacing: original, now: now,
                    existingState: state, enabled: replacement.status == .scheduled)
                : planner.validateScheduledReplacement(replacement, replacing: original, now: now,
                    existingState: state)
            try MonitoringSchedule.validateCapacity(for: state.rules, at: now)
        }
    }

    public func deleteRule(id: UUID, now: Date? = nil) throws {
        try update { state in
            guard let index = state.rules.firstIndex(where: { $0.id == id }) else { return }
            let rule = state.rules[index]
            let now = now ?? Date()
            if rule.isOneShot {
                try state.validateEditable(rule, at: now)
            } else if let active = state.activeLocks(at: now).first(where: { $0.id == id }) {
                state.rules[index].scheduledDeletionAt = active.endsAt
                return
            }
            state.rules.removeAll { $0.id == id }
            state.wakeState.requests.removeAll { $0.ruleID == id }
            if state.wakeState.pendingPurchase?.ruleID == id {
                state.wakeState.pendingPurchase = nil
            }
        }
    }

    public func cancelScheduledDeletion(id: UUID, now: Date? = nil) throws {
        try update { state in
            guard let index = state.rules.firstIndex(where: { $0.id == id }),
                  let recurrence = state.rules[index].recurrence,
                  let deletion = state.rules[index].scheduledDeletionAt
            else { throw LockValidationError.ruleNotFound }
            let now = now ?? Date()
            guard now < deletion else { throw LockValidationError.ruleNotFound }

            var stateWithoutRule = state
            stateWithoutRule.rules.remove(at: index)
            _ = try LockPlanner().makeRule(
                from: .recurring(recurrence: recurrence, targetSelectionID: state.rules[index].targetSelectionID),
                now: now,
                existingState: stateWithoutRule
            )
            state.rules[index].scheduledDeletionAt = nil
            try MonitoringSchedule.validateCapacity(for: state.rules, at: now)
        }
    }

    @discardableResult
    public func scheduleFreeWake(for lock: ActiveLock, at now: Date) throws -> WakeRequest {
        try update { state in
            let active = try activeOccurrence(matching: lock, in: state, at: now)
            guard active.endsAt.timeIntervalSince(now) > WakePolicy.freeDelay else {
                throw WakeError.freeWakeUnavailable
            }
            if let existing = state.wakeState.request(for: active), existing.source == .delayed {
                return existing
            }
            state.wakeState.requests.removeAll { $0.matches(active) }
            let request = WakeRequest(
                ruleID: active.id,
                occurrenceStartedAt: active.startedAt,
                requestedAt: now,
                wakesAt: now.addingTimeInterval(WakePolicy.freeDelay),
                source: .delayed
            )
            state.wakeState.requests.append(request)
            return request
        }
    }

    public func cancelFreeWake(for lock: ActiveLock, at now: Date) throws {
        try update { state in
            _ = try activeOccurrence(matching: lock, in: state, at: now)
            let originalCount = state.wakeState.requests.count
            state.wakeState.requests.removeAll { $0.matches(lock) && $0.source == .delayed && $0.wakesAt > now }
            guard state.wakeState.requests.count != originalCount else { throw WakeError.noWakeRequest }
        }
    }

    public func beginWakePurchase(for lock: ActiveLock, at now: Date) throws {
        try update { state in
            let active = try activeOccurrence(matching: lock, in: state, at: now)
            state.wakeState.pendingPurchase = WakePurchaseIntent(
                ruleID: active.id,
                occurrenceStartedAt: active.startedAt,
                requestedAt: now
            )
        }
    }

    public func abandonWakePurchase() throws {
        try update { state in
            state.wakeState.pendingPurchase = nil
        }
    }

    @discardableResult
    public func deliverWakePurchase(transactionID: UInt64, at now: Date) throws -> WakePurchaseDelivery {
        try update { state in
            guard !state.wakeState.hasHandled(transactionID: transactionID) else { return .alreadyHandled }
            guard let intent = state.wakeState.pendingPurchase,
                  let rule = state.rules.first(where: { $0.id == intent.ruleID }),
                  let active = rule.occurrence(containing: now),
                  active.startedAt == intent.occurrenceStartedAt,
                  now < state.wakeState.effectiveEnd(of: active)
            else {
                state.wakeState.pendingPurchase = nil
                state.wakeState.creditTransactionIDs.append(transactionID)
                return .credited
            }
            state.wakeState.requests.removeAll { $0.matches(active) }
            state.wakeState.requests.append(WakeRequest(
                ruleID: active.id,
                occurrenceStartedAt: active.startedAt,
                requestedAt: intent.requestedAt,
                wakesAt: now,
                source: .purchase,
                transactionID: transactionID
            ))
            state.wakeState.pendingPurchase = nil
            return .unlocked
        }
    }

    public func useWakeCredit(for lock: ActiveLock, at now: Date) throws {
        try update { state in
            let active = try activeOccurrence(matching: lock, in: state, at: now)
            guard let transactionID = state.wakeState.creditTransactionIDs.first else {
                throw WakeError.noWakeCredit
            }
            state.wakeState.creditTransactionIDs.removeFirst()
            state.wakeState.requests.removeAll { $0.matches(active) }
            state.wakeState.requests.append(WakeRequest(
                ruleID: active.id,
                occurrenceStartedAt: active.startedAt,
                requestedAt: now,
                wakesAt: now,
                source: .purchase,
                transactionID: transactionID
            ))
        }
    }

    private func activeOccurrence(matching lock: ActiveLock, in state: LockState, at now: Date) throws -> ActiveLock {
        guard let rule = state.rules.first(where: { $0.id == lock.id }),
              let active = rule.occurrence(containing: now),
              active.startedAt == lock.startedAt,
              now < state.wakeState.effectiveEnd(of: active)
        else { throw WakeError.activeLockNotFound }
        return active
    }

    private func update<T>(_ body: (inout LockState) throws -> T) throws -> T {
        let original = try repository.load()
        var state = original
        let result = try body(&state)
        if state != original { try repository.save(state) }
        return result
    }
}

private extension LockState {
    mutating func removeRulesDeleted(at date: Date) {
        let deletedIDs = Set(rules.filter { $0.isDeleted(at: date) }.map(\.id))
        guard !deletedIDs.isEmpty else { return }
        rules.removeAll { deletedIDs.contains($0.id) }
        wakeState.requests.removeAll { deletedIDs.contains($0.ruleID) }
        if let ruleID = wakeState.pendingPurchase?.ruleID, deletedIDs.contains(ruleID) {
            wakeState.pendingPurchase = nil
        }
    }
}
