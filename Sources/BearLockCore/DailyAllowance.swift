import Foundation

public enum DailyAllowanceError: Error, Equatable, Sendable {
    case invalidDailyLimit
    case missingTarget
    case notAvailableToday
    case invalidDuration
    case insufficientMinutes
    case grantAlreadyActive
    case grantNotActive
    case blockedByNormalLock
    case monitoringUnavailable
    case invalidGrant
    case invalidPaidDuration
}

public struct DailyAllowancePolicy: Codable, Equatable, Sendable {
    public static let allowedDailyLimits = [15, 30, 60, 120]
    public static let defaultDailyLimitMinutes = 60

    public var isEnabled: Bool
    public var targetSelection: LockTargetSelectionRef?
    public var dailyLimitMinutes: Int

    public init(
        isEnabled: Bool = false,
        targetSelection: LockTargetSelectionRef? = nil,
        dailyLimitMinutes: Int = Self.defaultDailyLimitMinutes
    ) {
        self.isEnabled = isEnabled
        self.targetSelection = targetSelection
        self.dailyLimitMinutes = dailyLimitMinutes
    }

    fileprivate func validate() throws {
        guard Self.allowedDailyLimits.contains(dailyLimitMinutes) else {
            throw DailyAllowanceError.invalidDailyLimit
        }
        if isEnabled {
            guard let targetSelection, targetSelection.tokenData != nil else {
                throw DailyAllowanceError.missingTarget
            }
        }
    }
}

public struct ScheduledDailyAllowancePolicy: Codable, Equatable, Sendable {
    public var policy: DailyAllowancePolicy
    public var effectiveAt: Date

    public init(policy: DailyAllowancePolicy, effectiveAt: Date) {
        self.policy = policy
        self.effectiveAt = effectiveAt
    }
}

public struct DailyAllowanceGrant: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var durationMinutes: Int
    public var expiresAt: Date
    public var purchaseTransactionID: UInt64?

    public init(id: UUID, durationMinutes: Int, expiresAt: Date, purchaseTransactionID: UInt64? = nil) {
        self.id = id
        self.durationMinutes = durationMinutes
        self.expiresAt = expiresAt
        self.purchaseTransactionID = purchaseTransactionID
    }

    public var monitoringName: String { "bearlock.daily.grant.\(id.uuidString)" }
    public var isPurchased: Bool { purchaseTransactionID != nil }
}

public struct DailyAllowanceState: Codable, Equatable, Sendable {
    public static let shieldStoreName = "bearlock.daily"
    public static let allowanceDurations = [5, 10, 15]

    public var currentPolicy: DailyAllowancePolicy
    public var pendingPolicy: ScheduledDailyAllowancePolicy?
    public var usageDayStart: Date?
    public var consumedMinutes: Int
    public var grant: DailyAllowanceGrant?
    public var lastPaidPurchaseTransactionID: UInt64?
    public var isConfigured: Bool { currentPolicy.targetSelection != nil || pendingPolicy != nil }

    public init(
        currentPolicy: DailyAllowancePolicy = DailyAllowancePolicy(),
        pendingPolicy: ScheduledDailyAllowancePolicy? = nil,
        usageDayStart: Date? = nil,
        consumedMinutes: Int = 0,
        grant: DailyAllowanceGrant? = nil,
        lastPaidPurchaseTransactionID: UInt64? = nil
    ) {
        self.currentPolicy = currentPolicy
        self.pendingPolicy = pendingPolicy
        self.usageDayStart = usageDayStart
        self.consumedMinutes = consumedMinutes
        self.grant = grant
        self.lastPaidPurchaseTransactionID = lastPaidPurchaseTransactionID
    }

    public func policy(at date: Date, calendar: Calendar = .current) -> DailyAllowancePolicy {
        guard let pendingPolicy, pendingPolicy.effectiveAt <= date else { return currentPolicy }
        return pendingPolicy.policy
    }

    public func policyForEditing(at date: Date, calendar: Calendar = .current) -> DailyAllowancePolicy {
        guard let pendingPolicy, pendingPolicy.effectiveAt > date else { return policy(at: date, calendar: calendar) }
        return pendingPolicy.policy
    }

    public func requiresBoundaryMonitoring(at date: Date, calendar: Calendar = .current) -> Bool {
        if policy(at: date, calendar: calendar).isEnabled { return true }
        return pendingPolicy.map { $0.effectiveAt > date && $0.policy.isEnabled } ?? false
    }

    public func remainingMinutes(at date: Date, calendar: Calendar = .current) -> Int {
        let policy = policy(at: date, calendar: calendar)
        guard policy.isEnabled else { return 0 }
        let today = calendar.startOfDay(for: date)
        let used = usageDayStart == today ? consumedMinutes : 0
        return max(0, policy.dailyLimitMinutes - used)
    }

    public func activeGrant(at date: Date) -> DailyAllowanceGrant? {
        guard let grant, date < grant.expiresAt else { return nil }
        return grant
    }

    public func availableDurations(at date: Date, calendar: Calendar = .current) -> [Int] {
        let policy = policy(at: date, calendar: calendar)
        guard policy.isEnabled,
              policy.targetSelection?.tokenData != nil,
              activeGrant(at: date) == nil,
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        else { return [] }

        let untilBoundary = max(0, Int(dayEnd.timeIntervalSince(date) / 60))
        let maximum = min(remainingMinutes(at: date, calendar: calendar), untilBoundary)
        return Self.allowanceDurations.filter { $0 <= maximum }
    }

    public mutating func configure(_ policy: DailyAllowancePolicy, at date: Date, calendar: Calendar = .current) throws {
        try policy.validate()
        if let pendingPolicy, pendingPolicy.effectiveAt <= date {
            currentPolicy = pendingPolicy.policy
            self.pendingPolicy = nil
        }

        if currentPolicy.targetSelection == nil, pendingPolicy == nil {
            currentPolicy = policy
            return
        }

        let tomorrow = try calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            .unwrap(or: DailyAllowanceError.invalidGrant)
        pendingPolicy = ScheduledDailyAllowancePolicy(policy: policy, effectiveAt: tomorrow)
    }

    @discardableResult
    public mutating func beginGrant(
        minutes: Int,
        id: UUID = UUID(),
        at date: Date,
        calendar: Calendar = .current
    ) throws -> DailyAllowanceGrant {
        guard Self.allowanceDurations.contains(minutes) else { throw DailyAllowanceError.invalidDuration }
        guard activeGrant(at: date) == nil else { throw DailyAllowanceError.grantAlreadyActive }
        guard availableDurations(at: date, calendar: calendar).contains(minutes) else {
            let policy = policy(at: date, calendar: calendar)
            guard policy.isEnabled, policy.targetSelection?.tokenData != nil else {
                throw DailyAllowanceError.notAvailableToday
            }
            throw DailyAllowanceError.insufficientMinutes
        }

        let value = DailyAllowanceGrant(id: id, durationMinutes: minutes, expiresAt: date.addingTimeInterval(TimeInterval(minutes * 60)))
        let today = calendar.startOfDay(for: date)
        let usedToday = usageDayStart == today ? consumedMinutes : 0
        usageDayStart = today
        consumedMinutes = usedToday + minutes
        grant = value
        return value
    }

    public mutating func endGrant(id: UUID, at date: Date, calendar: Calendar = .current) throws {
        guard var grant, grant.id == id else { throw DailyAllowanceError.invalidGrant }
        guard date < grant.expiresAt else { throw DailyAllowanceError.grantNotActive }
        if !grant.isPurchased, usageDayStart == calendar.startOfDay(for: date) {
            let remainingWholeMinutes = max(0, Int(grant.expiresAt.timeIntervalSince(date) / 60))
            let returnedMinutes = min(grant.durationMinutes, remainingWholeMinutes)
            consumedMinutes = max(0, consumedMinutes - returnedMinutes)
        }
        grant.expiresAt = date
        self.grant = grant
    }

    @discardableResult
    public mutating func beginPaidGrant(
        minutes: Int,
        id: UUID = UUID(),
        transactionID: UInt64,
        at date: Date,
        calendar: Calendar = .current
    ) throws -> DailyAllowanceGrant {
        let activePolicy = policy(at: date, calendar: calendar)
        guard minutes > (Self.allowanceDurations.last ?? 0),
              let expiresAt = calendar.date(byAdding: .minute, value: minutes, to: date),
              expiresAt > date,
              activeGrant(at: date) == nil,
              activePolicy.isEnabled,
              activePolicy.targetSelection?.tokenData != nil
        else { throw DailyAllowanceError.invalidPaidDuration }

        let grant = DailyAllowanceGrant(
            id: id,
            durationMinutes: minutes,
            expiresAt: expiresAt,
            purchaseTransactionID: transactionID
        )
        self.grant = grant
        lastPaidPurchaseTransactionID = transactionID
        return grant
    }

    public func shieldTarget(at date: Date, calendar: Calendar = .current) -> LockTargetSelectionRef? {
        let policy = policy(at: date, calendar: calendar)
        guard policy.isEnabled,
              policy.targetSelection?.tokenData != nil,
              activeGrant(at: date) == nil
        else { return nil }
        return policy.targetSelection
    }

    public func isNearLocalDayBoundary(at date: Date, calendar: Calendar = .current) -> Bool {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else { return false }
        return Int(dayEnd.timeIntervalSince(date) / 60) < 5
    }
}

public enum DailyAllowanceAccessState: Equatable, Sendable {
    case notConfigured
    case disabled
    case blockedByNormalLock
    case temporarilyUnlocked(DailyAllowanceGrant)
    case exhausted
    case dayBoundaryTooClose
    case available
}

private extension Optional {
    func unwrap<E: Error>(or error: E) throws -> Wrapped {
        guard let self else { throw error }
        return self
    }
}
