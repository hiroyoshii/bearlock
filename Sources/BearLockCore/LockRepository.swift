import Foundation

public struct LockState: Codable, Equatable, Sendable {
    public var targetSelections: [LockTargetSelectionRef]
    public var rules: [LockRule]
    public var activeLock: ActiveLock?
    public var completedLocks: [ActiveLock]

    public init(
        targetSelections: [LockTargetSelectionRef] = [],
        rules: [LockRule] = [],
        activeLock: ActiveLock? = nil,
        completedLocks: [ActiveLock] = []
    ) {
        self.targetSelections = targetSelections
        self.rules = rules
        self.activeLock = activeLock
        self.completedLocks = completedLocks
    }
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

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(LockState.self, from: data)
    }

    public func save(_ state: LockState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
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

    public func saveTargetSelection(_ selection: LockTargetSelectionRef) throws {
        state.targetSelections.removeAll { $0.id == selection.id }
        state.targetSelections.append(selection)
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
