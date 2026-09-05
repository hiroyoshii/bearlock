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
}

public final class JSONFileLockRepository: LockRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> LockState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LockState()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LockState.self, from: data)
        } catch {
            try quarantineCorruptedState()
            return LockState()
        }
    }

    public func save(_ state: LockState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func quarantineCorruptedState() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(timestamp)")
            .appendingPathExtension(fileURL.pathExtension.isEmpty ? "json" : fileURL.pathExtension)
        try FileManager.default.moveItem(at: fileURL, to: backupURL)
    }
}

public actor LockStore {
    private let repository: LockRepository
    private var state: LockState

    public init(repository: LockRepository) throws {
        self.repository = repository
        self.state = try repository.load()
    }

    public func snapshot() -> LockState {
        state
    }

    @discardableResult
    public func saveTargetSelection(_ selection: LockTargetSelectionRef) throws -> LockTargetSelectionRef {
        var savedSelection = selection
        if let tokenData = selection.tokenData,
           let existing = state.targetSelections.last(where: { $0.tokenData == tokenData }) {
            savedSelection.id = existing.id
        }

        state.targetSelections.removeAll { $0.id == savedSelection.id }
        state.targetSelections.append(savedSelection)
        try repository.save(state)
        return savedSelection
    }

    public func targetSelection(id: UUID) -> LockTargetSelectionRef? {
        state.targetSelections.last { $0.id == id }
    }

    public func recordRecentLockTarget(targetSelectionID: UUID, usedAt: Date) throws {
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

        try repository.save(state)
    }

    public func setRecentLockTargetPinned(id: UUID, pinned: Bool, at date: Date) throws {
        guard let index = state.recentLockTargets.firstIndex(where: { $0.id == id }) else {
            throw RecentLockTargetError.recentTargetNotFound
        }

        if pinned,
           !state.recentLockTargets[index].isPinned,
           state.recentLockTargets.filter(\.isPinned).count >= 3 {
            throw RecentLockTargetError.pinnedTargetLimitReached
        }

        state.recentLockTargets[index].pinnedAt = pinned ? date : nil
        try repository.save(state)
    }

    public func deleteRecentLockTarget(id: UUID) throws {
        guard state.recentLockTargets.contains(where: { $0.id == id }) else {
            throw RecentLockTargetError.recentTargetNotFound
        }

        state.recentLockTargets.removeAll { $0.id == id }
        try repository.save(state)
    }

    public func addRule(_ rule: LockRule) throws {
        state.rules.removeAll { $0.id == rule.id }
        state.rules.append(rule)
        try repository.save(state)
    }

    public func replaceRule(_ rule: LockRule, now: Date) throws {
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
        try repository.save(state)
    }

    public func deleteRule(id: UUID, now: Date) throws {
        if let active = state.activeLock, active.sourceRuleID == id, active.isActive(at: now) {
            throw LockValidationError.activeLockIsImmutable
        }
        state.rules.removeAll { $0.id == id }
        try repository.save(state)
    }

    public func activate(_ activeLock: ActiveLock) throws {
        state.activeLock = activeLock
        try repository.save(state)
    }

    public func clearActiveLock(id: UUID) throws {
        guard state.activeLock?.id == id else {
            return
        }

        state.activeLock = nil
        try repository.save(state)
    }

    public func completeActiveLock(at date: Date) throws -> ActiveLock? {
        guard let active = state.activeLock, active.endsAt <= date else {
            return nil
        }

        state.activeLock = nil
        state.completedLocks.append(active)
        try repository.save(state)
        return active
    }

    public func completeExpiredOneShotRules(at date: Date) throws -> [LockRule] {
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

        if !completed.isEmpty {
            try repository.save(state)
        }

        return completed
    }
}
