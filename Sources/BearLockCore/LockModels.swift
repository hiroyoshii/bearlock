import Foundation

public struct LockTargetSelectionRef: Codable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String
    public var tokenData: Data?

    public init(id: UUID = UUID(), displayName: String = "Selected apps", tokenData: Data? = nil) {
        self.id = id
        self.displayName = displayName
        self.tokenData = tokenData
    }
}

public struct RecentLockTarget: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var targetSelectionID: UUID
    public var lastUsedAt: Date
    public var pinnedAt: Date?

    public init(
        id: UUID = UUID(),
        targetSelectionID: UUID,
        lastUsedAt: Date,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.targetSelectionID = targetSelectionID
        self.lastUsedAt = lastUsedAt
        self.pinnedAt = pinnedAt
    }

    public var isPinned: Bool {
        pinnedAt != nil
    }
}

public struct LockRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: LockRuleKind
    public var startsAt: Date
    public var duration: TimeInterval
    public var recurrence: RecurrenceRule?
    public var targetSelectionID: UUID
    public var status: LockRuleStatus

    public init(
        id: UUID = UUID(),
        kind: LockRuleKind,
        startsAt: Date,
        duration: TimeInterval,
        recurrence: RecurrenceRule? = nil,
        targetSelectionID: UUID,
        status: LockRuleStatus = .scheduled
    ) {
        self.id = id
        self.kind = kind
        self.startsAt = startsAt
        self.duration = duration
        self.recurrence = recurrence
        self.targetSelectionID = targetSelectionID
        self.status = status
    }

    public var endsAt: Date {
        startsAt.addingTimeInterval(duration)
    }

    public var isOneShot: Bool {
        kind == .immediate || kind == .delayed || kind == .fixedDateTime
    }

    public func contains(_ date: Date) -> Bool {
        startsAt <= date && date < endsAt
    }
}

public enum LockRuleKind: String, Codable, Equatable, Sendable {
    case immediate
    case delayed
    case fixedDateTime
    case recurring
}

public enum LockRuleStatus: String, Codable, Equatable, Sendable {
    case scheduled
    case disabled
    case completed
}

public struct ActiveLock: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sourceRuleID: UUID?
    public var startedAt: Date
    public var endsAt: Date
    public var targetSelectionID: UUID

    public init(
        id: UUID = UUID(),
        sourceRuleID: UUID?,
        startedAt: Date,
        endsAt: Date,
        targetSelectionID: UUID
    ) {
        self.id = id
        self.sourceRuleID = sourceRuleID
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.targetSelectionID = targetSelectionID
    }

    public func remainingTime(at date: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(date))
    }

    public func isActive(at date: Date) -> Bool {
        startedAt <= date && date < endsAt
    }
}

public enum LockCreationRequest: Equatable, Sendable {
    case now(duration: TimeInterval, targetSelectionID: UUID)
    case delayed(delay: TimeInterval, duration: TimeInterval, targetSelectionID: UUID)
    case fixed(startsAt: Date, duration: TimeInterval, targetSelectionID: UUID)
    case recurring(recurrence: RecurrenceRule, targetSelectionID: UUID)
}

public enum LockValidationError: Error, Equatable, Sendable {
    case nonPositiveDuration
    case startDateInPast
    case emptyWeekdays
    case overlappingLock
    case activeLockIsImmutable
    case ruleAlreadyStarted
    case notRecurringRule
}
