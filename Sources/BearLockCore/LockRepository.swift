import Foundation

public struct LockState: Codable, Equatable, Sendable {
    public var targetSelections: [LockTargetSelectionRef]
    public var recentLockTargets: [RecentLockTarget]
    public var rules: [LockRule]

    public init(
        targetSelections: [LockTargetSelectionRef] = [],
        recentLockTargets: [RecentLockTarget] = [],
        rules: [LockRule] = []
    ) {
        self.targetSelections = targetSelections
        self.recentLockTargets = recentLockTargets
        self.rules = rules
    }

    public func activeLocks(at date: Date) -> [ActiveLock] {
        rules.filter { $0.status == .scheduled }
            .compactMap { $0.occurrence(containing: date) }
            .sorted { $0.startsAt < $1.startsAt }
            .map { LockPlanner().activeLock(from: $0) }
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

    public func createRule(_ request: LockCreationRequest, now: Date? = nil) throws -> LockRule {
        try update { state in
            let rule = try LockPlanner().makeRule(from: request, now: now ?? Date(), existingRules: state.rules)
            state.rules.append(rule)
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
            try original.validateEditable(at: now)
            let planner = LockPlanner()
            state.rules[index] = try original.kind == .recurring
                ? planner.validateRecurringReplacement(replacement, replacing: original, now: now,
                    existingRules: state.rules, enabled: replacement.status == .scheduled)
                : planner.validateScheduledReplacement(replacement, replacing: original, now: now,
                    existingRules: state.rules)
        }
    }

    public func deleteRule(id: UUID, now: Date? = nil) throws {
        try update { state in
            guard let rule = state.rules.first(where: { $0.id == id }) else { return }
            try rule.validateEditable(at: now ?? Date())
            state.rules.removeAll { $0.id == id }
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
        at now: Date? = nil,
        apply: @Sendable ([LockTargetSelectionRef]) throws -> Void,
        record: @Sendable (String) -> Void
    ) throws -> LockState {
        try LockLifecycle(repository: repository).reconcile(at: now, apply: apply, record: record)
    }
}
