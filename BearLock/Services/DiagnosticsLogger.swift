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
    var lastWarning: String
    var lastSelectionEvent: String
    var lastLockEvent: String
    var lastDeviceActivityEvent: String
    var lastShieldEvent: String
    var lastShieldConfigurationEvent: String
    var safetyPolicy: String
    var appGroupPath: String
    var diagnosticsWritable: Bool
    var bundleIdentifier: String
    var appVersion: String
}

extension DiagnosticEvent {
    var summary: String {
        if let detail, !detail.isEmpty {
            return "\(name): \(detail)"
        }
        return name
    }
}

extension DiagnosticsSnapshot {
    func lastEvent(named prefix: String) -> DiagnosticEvent? {
        events.first { $0.name.hasPrefix(prefix) }
    }

    func lastEvent(level: DiagnosticLevel) -> DiagnosticEvent? {
        events.first { $0.level == level }
    }
}

final class DiagnosticsLogger: @unchecked Sendable {
    static let shared = DiagnosticsLogger()

    private let logger = Logger(subsystem: "com.hiyozoo.bearlock", category: "diagnostics")
    private let queue = DispatchQueue(label: "bearlock.diagnostics.memory")
    private var events: [DiagnosticEvent] = []
    private let maxEvents = 50
    private init() {}

    func record(_ name: String, level: DiagnosticLevel = .info, detail: String? = nil) {
        logger.log(level: osLogType(for: level), "\(name, privacy: .public) \(detail ?? "", privacy: .public)")
        queue.sync {
            events.insert(DiagnosticEvent(level: level, name: name, detail: detail), at: 0)
            if events.count > maxEvents {
                events.removeLast(events.count - maxEvents)
            }
        }
    }

    func snapshot() -> DiagnosticsSnapshot {
        queue.sync { DiagnosticsSnapshot(events: events) }
    }

    func clear() {
        queue.sync { events.removeAll() }
    }

    func isWritable() -> Bool {
        false
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
