import BearLockCore
import Foundation

enum BearLockSafetyPolicy {
    static var maximumDuration: TimeInterval? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") || arguments.contains("--screenshot") {
            return nil
        }
        return 5 * 60
        #else
        return nil
        #endif
    }

    static var diagnosticsText: String {
        if let maximumDuration {
            return L10n.format("Debug safety: max %d min", Int(maximumDuration / 60))
        }
        return L10n.string("Release limits")
    }

    static func validate(_ request: LockCreationRequest) throws {
        try validateDuration(request.duration)
    }

    static func validateDuration(_ duration: TimeInterval) throws {
        guard let maximumDuration else {
            return
        }

        if duration > maximumDuration {
            throw BearLockSafetyError.durationTooLong(maximumMinutes: Int(maximumDuration / 60))
        }
    }
}

enum BearLockSafetyError: LocalizedError {
    case durationTooLong(maximumMinutes: Int)

    var errorDescription: String? {
        switch self {
        case let .durationTooLong(maximumMinutes):
            return L10n.format("Debug safety limit: lock duration is max %d min.", maximumMinutes)
        }
    }
}

private extension LockCreationRequest {
    var duration: TimeInterval {
        switch self {
        case let .now(duration, _):
            return duration
        case let .delayed(_, duration, _):
            return duration
        case let .fixed(_, duration, _):
            return duration
        case let .recurring(recurrence, _):
            return recurrence.duration
        }
    }
}
