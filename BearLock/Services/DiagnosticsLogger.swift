import Foundation
import OSLog

enum DiagnosticLevel: String, Codable, Sendable {
    case info
    case warning
    case error
}

struct DiagnosticEvent: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var level: DiagnosticLevel
    var name: String
    var detail: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        level: DiagnosticLevel = .info,
        name: String,
        detail: String? = nil
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.name = name
        self.detail = detail
    }
}

struct DiagnosticsSnapshot: Codable, Equatable, Sendable {
    var events: [DiagnosticEvent]

    static let empty = DiagnosticsSnapshot(events: [])
}

struct DiagnosticsSummary: Equatable {
    var authorizationStatus: String
    var targetSelectionCount: Int
    var scheduledRuleCount: Int
    var recurringRuleCount: Int
    var activeLockStatus: String
    var lastError: String
    var safetyPolicy: String
    var appGroupPath: String
    var diagnosticsWritable: Bool
    var bundleIdentifier: String
    var appVersion: String
}

final class DiagnosticsLogger: @unchecked Sendable {
    static let shared = DiagnosticsLogger()

    private let logger = Logger(subsystem: "com.hiyozoo.bearlock", category: "diagnostics")
    private let queue = DispatchQueue(label: "bearlock.diagnostics")
    private let maxEvents = 50
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(_ name: String, level: DiagnosticLevel = .info, detail: String? = nil) {
        logger.log(level: osLogType(for: level), "\(name, privacy: .public) \(detail ?? "", privacy: .public)")

        queue.sync {
            var snapshot = self.loadUnlocked()
            snapshot.events.insert(DiagnosticEvent(level: level, name: name, detail: detail), at: 0)
            if snapshot.events.count > self.maxEvents {
                snapshot.events.removeLast(snapshot.events.count - self.maxEvents)
            }
            self.saveUnlocked(snapshot)
        }
    }

    func snapshot() -> DiagnosticsSnapshot {
        queue.sync {
            loadUnlocked()
        }
    }

    func clear() {
        queue.sync {
            saveUnlocked(.empty)
        }
    }

    func isWritable() -> Bool {
        let probeURL = AppGroup.containerURL.appending(path: "diagnostics-write-probe.txt")
        do {
            try FileManager.default.createDirectory(at: AppGroup.containerURL, withIntermediateDirectories: true)
            try "ok".write(to: probeURL, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: probeURL)
            return true
        } catch {
            record("Diagnostics.writeProbe.failed", level: .error, detail: error.localizedDescription)
            return false
        }
    }

    private func loadUnlocked() -> DiagnosticsSnapshot {
        guard FileManager.default.fileExists(atPath: AppGroup.diagnosticsURL.path) else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: AppGroup.diagnosticsURL)
            return try decoder.decode(DiagnosticsSnapshot.self, from: data)
        } catch {
            logger.error("Diagnostics.load.failed \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    private func saveUnlocked(_ snapshot: DiagnosticsSnapshot) {
        do {
            try FileManager.default.createDirectory(at: AppGroup.containerURL, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: AppGroup.diagnosticsURL, options: [.atomic])
        } catch {
            logger.error("Diagnostics.save.failed \(error.localizedDescription, privacy: .public)")
        }
    }

    private func osLogType(for level: DiagnosticLevel) -> OSLogType {
        switch level {
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}
