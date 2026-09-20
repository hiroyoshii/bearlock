import Foundation

enum AppGroup {
    static let identifier = "group.com.hiyozoo.bearlock"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            preconditionFailure("Missing App Group container: \(identifier)")
        }
        return url
    }

    static var lockStateURL: URL {
        containerURL.appending(path: "lock-state.json")
    }
}
