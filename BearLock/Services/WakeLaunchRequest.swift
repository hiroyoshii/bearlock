import Foundation

enum WakeLaunchRequest {
    private static let key = "wakeLaunchRequestedAt"
    private static let validity: TimeInterval = 5 * 60

    static func record(at date: Date = Date()) {
        UserDefaults(suiteName: AppGroup.identifier)?.set(date.timeIntervalSince1970, forKey: key)
    }

    static func consume(at date: Date = Date()) -> Bool {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier),
              let timestamp = defaults.object(forKey: key) as? Double
        else { return false }
        defaults.removeObject(forKey: key)
        let age = date.timeIntervalSince1970 - timestamp
        return age >= 0 && age < validity
    }
}
