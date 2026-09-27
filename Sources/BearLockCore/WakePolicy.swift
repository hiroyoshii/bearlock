import Foundation

public enum WakePolicy {
    public static let freeDelay: TimeInterval = 30 * 60
    public static let minimumPaidRemainingTime: TimeInterval = 10 * 60
}

public enum WakeSource: String, Codable, Equatable, Sendable {
    case delayed
    case purchase
}

public struct WakeRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var ruleID: UUID
    public var occurrenceStartedAt: Date
    public var requestedAt: Date
    public var wakesAt: Date
    public var source: WakeSource
    public var transactionID: UInt64?

    public init(
        id: UUID = UUID(),
        ruleID: UUID,
        occurrenceStartedAt: Date,
        requestedAt: Date,
        wakesAt: Date,
        source: WakeSource,
        transactionID: UInt64? = nil
    ) {
        self.id = id
        self.ruleID = ruleID
        self.occurrenceStartedAt = occurrenceStartedAt
        self.requestedAt = requestedAt
        self.wakesAt = wakesAt
        self.source = source
        self.transactionID = transactionID
    }

    public func matches(_ lock: ActiveLock) -> Bool {
        ruleID == lock.id && occurrenceStartedAt == lock.startedAt
    }
}

public struct WakePurchaseIntent: Codable, Equatable, Sendable {
    public var ruleID: UUID
    public var occurrenceStartedAt: Date
    public var requestedAt: Date

    public init(ruleID: UUID, occurrenceStartedAt: Date, requestedAt: Date) {
        self.ruleID = ruleID
        self.occurrenceStartedAt = occurrenceStartedAt
        self.requestedAt = requestedAt
    }
}

public struct WakeState: Codable, Equatable, Sendable {
    public var requests: [WakeRequest]
    public var pendingPurchase: WakePurchaseIntent?
    public var creditTransactionIDs: [UInt64]

    public init(
        requests: [WakeRequest] = [],
        pendingPurchase: WakePurchaseIntent? = nil,
        creditTransactionIDs: [UInt64] = []
    ) {
        self.requests = requests
        self.pendingPurchase = pendingPurchase
        self.creditTransactionIDs = creditTransactionIDs
    }

    public func request(for lock: ActiveLock) -> WakeRequest? {
        requests.last { $0.matches(lock) }
    }

    public func effectiveEnd(of lock: ActiveLock) -> Date {
        requests
            .filter { $0.matches(lock) }
            .map(\.wakesAt)
            .filter { lock.startedAt <= $0 && $0 < lock.endsAt }
            .min() ?? lock.endsAt
    }

    public func hasHandled(transactionID: UInt64) -> Bool {
        creditTransactionIDs.contains(transactionID)
            || requests.contains { $0.transactionID == transactionID }
    }
}

public enum WakeError: Error, Equatable, Sendable {
    case activeLockNotFound
    case freeWakeUnavailable
    case noWakeRequest
    case noWakeCredit
}

public enum WakePurchaseDelivery: Equatable, Sendable {
    case unlocked
    case credited
    case alreadyHandled
}
