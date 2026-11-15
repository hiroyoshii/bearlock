import Foundation

enum ShieldLaunchDestination: String, Equatable {
    case wake
    case dailyAllowance
}

enum ShieldLaunchRequest {
    private static let key = "shieldLaunchDestination"
    private static let validity: TimeInterval = 5 * 60

    static func record(_ destination: ShieldLaunchDestination, at date: Date = Date()) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        defaults?.set(destination.rawValue, forKey: key)
        defaults?.set(date.timeIntervalSince1970, forKey: "shieldLaunchRequestedAt")
    }

    static func consume(at date: Date = Date()) -> ShieldLaunchDestination? {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier),
              let rawValue = defaults.string(forKey: key),
              let destination = ShieldLaunchDestination(rawValue: rawValue),
              let timestamp = defaults.object(forKey: "shieldLaunchRequestedAt") as? Double
        else { return nil }
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: "shieldLaunchRequestedAt")
        let age = date.timeIntervalSince1970 - timestamp
        return age >= 0 && age < validity ? destination : nil
    }
}
