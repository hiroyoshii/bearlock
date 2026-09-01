import Foundation

enum ShieldConfigurationDiagnostics {
    private static let appGroupIdentifier = "group.com.hiyozoo.bearlock"
    private static let maxEvents = 50

    static func record(_ name: String, detail: String? = nil) {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = containerURL.appending(path: "diagnostics.json")

        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            var snapshot = try load(from: url)
            if snapshot.events.first?.name == name, snapshot.events.first?.detail == detail {
                return
            }
            snapshot.events.insert(Event(level: "info", name: name, detail: detail), at: 0)
            if snapshot.events.count > maxEvents {
                snapshot.events.removeLast(snapshot.events.count - maxEvents)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    private static func load(from url: URL) throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Snapshot(events: [])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: Data(contentsOf: url))
    }
}

private struct Snapshot: Codable {
    var events: [Event]
}

private struct Event: Codable {
    var id = UUID()
    var date = Date()
    var level: String
    var name: String
    var detail: String?
}
