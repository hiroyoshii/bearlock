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

public struct SingleLockSchedule: Codable, Equatable, Sendable {
    public var kind: SingleLockKind
    public var startsAt: Date
    public var duration: TimeInterval
    public var endsAt: Date { startsAt.addingTimeInterval(duration) }
    public var interval: DateInterval { DateInterval(start: startsAt, end: endsAt) }
}

public enum SingleLockKind: String, Codable, Sendable {
    case immediate, delayed, fixedDateTime
}

public enum LockSchedule: Codable, Equatable, Sendable {
    case single(SingleLockSchedule)
    case recurring(RecurrenceRule)
}

public struct LockRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var schedule: LockSchedule
    public var targetSelectionID: UUID
    public var status: LockRuleStatus
    /// The current recurring occurrence remains effective before this boundary; later ones do not.
    public var scheduledDeletionAt: Date?

    public init(id: UUID = UUID(), kind: SingleLockKind, startsAt: Date, duration: TimeInterval,
                targetSelectionID: UUID, status: LockRuleStatus = .scheduled,
                scheduledDeletionAt: Date? = nil) {
        self.id = id
        self.schedule = .single(SingleLockSchedule(kind: kind, startsAt: startsAt, duration: duration))
        self.targetSelectionID = targetSelectionID
        self.status = status
        self.scheduledDeletionAt = scheduledDeletionAt
    }

    public init(id: UUID = UUID(), recurrence: RecurrenceRule, targetSelectionID: UUID,
                status: LockRuleStatus = .scheduled, scheduledDeletionAt: Date? = nil) {
        self.id = id
        self.schedule = .recurring(recurrence)
        self.targetSelectionID = targetSelectionID
        self.status = status
        self.scheduledDeletionAt = scheduledDeletionAt
    }

    public var single: SingleLockSchedule? {
        if case let .single(value) = schedule { return value }
        return nil
    }
    public var recurrence: RecurrenceRule? {
        if case let .recurring(value) = schedule { return value }
        return nil
    }
    public var kind: LockRuleKind {
        switch schedule {
        case .recurring: return .recurring
        case let .single(value):
            switch value.kind {
            case .immediate: return .immediate
            case .delayed: return .delayed
            case .fixedDateTime: return .fixedDateTime
            }
        }
    }
    public var isOneShot: Bool { single != nil }

    public func isDeleted(at date: Date) -> Bool {
        scheduledDeletionAt.map { $0 <= date } ?? false
    }

    public func isScheduled(at date: Date) -> Bool {
        status == .scheduled && !isDeleted(at: date)
    }

    /// The interval to display/register; disabled schedules can still be previewed.
    public func nextInterval(after date: Date) -> DateInterval? {
        let interval: DateInterval?
        switch schedule {
        case let .single(value): interval = value.endsAt > date ? value.interval : nil
        case let .recurring(value): interval = value.nextInterval(after: date)
        }
        guard let interval,
              scheduledDeletionAt.map({ interval.start < $0 }) ?? true
        else { return nil }
        return interval
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
}

/// A presentation value derived from a rule occurrence; never persisted.
public struct ActiveLock: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endsAt: Date
    public var targetSelectionID: UUID

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endsAt: Date,
        targetSelectionID: UUID
    ) {
        self.id = id
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
    case ruleNotFound
    case nonPositiveDuration
    case startDateInPast
    case emptyWeekdays
    case overlappingLock
    case activeLockIsImmutable
    case ruleAlreadyStarted
    case notRecurringRule
    case monitoringCapacityExceeded
}
