import Foundation

enum AppGroup {
    static let identifier = "group.com.example.bearlock"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var lockStateURL: URL {
        containerURL.appending(path: "lock-state.json")
    }

    static var selectionURL: URL {
        containerURL.appending(path: "family-activity-selection.plist")
    }
}
