import Foundation

public struct LockState: Codable, Equatable, Sendable {
    public var targetSelections: [LockTargetSelectionRef]
    public var recentLockTargets: [RecentLockTarget]
    public var rules: [LockRule]
    public var activeLock: ActiveLock?
    public var completedLocks: [ActiveLock]

    public init(
        targetSelections: [LockTargetSelectionRef] = [],
        recentLockTargets: [RecentLockTarget] = [],
        rules: [LockRule] = [],
        activeLock: ActiveLock? = nil,
        completedLocks: [ActiveLock] = []
    ) {
        self.targetSelections = targetSelections
        self.recentLockTargets = recentLockTargets
        self.rules = rules
        self.activeLock = activeLock
        self.completedLocks = completedLocks
    }

    private enum CodingKeys: String, CodingKey {
        case targetSelections
        case recentLockTargets
        case rules
        case activeLock
        case completedLocks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetSelections = try container.decodeIfPresent([LockTargetSelectionRef].self, forKey: .targetSelections) ?? []
        recentLockTargets = try container.decodeIfPresent([RecentLockTarget].self, forKey: .recentLockTargets) ?? []
        rules = try container.decodeIfPresent([LockRule].self, forKey: .rules) ?? []
        activeLock = try container.decodeIfPresent(ActiveLock.self, forKey: .activeLock)
        completedLocks = try container.decodeIfPresent([ActiveLock].self, forKey: .completedLocks) ?? []
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
    /// Serializes the whole read/decide/effect/write operation, including across processes.
    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T
}

public actor LockStore {
    private let repository: LockRepository

    public init(repository: LockRepository) throws {
        self.repository = repository
    }

    public func snapshot() throws -> LockState {
        try repository.load()
    }

    @discardableResult
    public func saveTargetSelection(_ selection: LockTargetSelectionRef) throws -> LockTargetSelectionRef {
        try update { state in
            var savedSelection = selection
            if let tokenData = selection.tokenData,
               let existing = state.targetSelections.last(where: { $0.tokenData == tokenData }) {
                savedSelection.id = existing.id
            }

            state.targetSelections.removeAll { $0.id == savedSelection.id }
            state.targetSelections.append(savedSelection)
            return savedSelection
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

    public func addRule(_ rule: LockRule) throws {
        try update { state in
            state.rules.removeAll { $0.id == rule.id }
            state.rules.append(rule)
        }
    }

    public func replaceRule(_ rule: LockRule, now: Date) throws {
        try update { state in
            if let active = state.activeLock, active.sourceRuleID == rule.id, active.isActive(at: now) {
                if rule.kind != .recurring {
                    throw LockValidationError.activeLockIsImmutable
                }
            }
            if let original = state.rules.first(where: { $0.id == rule.id }), original.startsAt <= now {
                if original.kind != .recurring {
                    throw LockValidationError.ruleAlreadyStarted
                }
            }
            state.rules.removeAll { $0.id == rule.id }
            state.rules.append(rule)
        }
    }

    public func deleteRule(id: UUID, now: Date) throws {
        try update { state in
            if let active = state.activeLock, active.sourceRuleID == id, active.isActive(at: now) {
                throw LockValidationError.activeLockIsImmutable
            }
            state.rules.removeAll { $0.id == id }
        }
    }

    public func activate(_ activeLock: ActiveLock) throws {
        try update { state in
            state.activeLock = activeLock
        }
    }

    public func clearActiveLock(id: UUID) throws {
        try update { state in
            guard state.activeLock?.id == id else {
                return
            }

            state.activeLock = nil
        }
    }

    public func completeActiveLock(at date: Date) throws -> ActiveLock? {
        try update { state in
            guard let active = state.activeLock, active.endsAt <= date else {
                return nil
            }

            state.activeLock = nil
            state.completedLocks.append(active)
            return active
        }
    }

    public func completeExpiredOneShotRules(at date: Date) throws -> [LockRule] {
        try update { state in
            var completed: [LockRule] = []

            for index in state.rules.indices {
                guard state.rules[index].status == .scheduled,
                      state.rules[index].isOneShot,
                      state.rules[index].endsAt <= date
                else {
                    continue
                }

                state.rules[index].status = .completed
                completed.append(state.rules[index])
            }


            return completed
        }
    }

    private func update<T>(_ body: (inout LockState) throws -> T) throws -> T {
        try repository.withExclusiveAccess {
            let original = try repository.load()
            var state = original
            let result = try body(&state)
            if state != original { try repository.save(state) }
            return result
        }
    }

    public func reconcile(
        event: LockLifecycleEvent,
        at now: Date,
        apply: @Sendable (ActiveLock, LockTargetSelectionRef?) throws -> Void,
        clear: @Sendable () -> Void,
        record: @Sendable (String) -> Void
    ) throws -> LockState {
        try LockLifecycle(repository: repository).reconcile(
            event: event, at: now, apply: apply, clear: clear, record: record
        )
    }
}
