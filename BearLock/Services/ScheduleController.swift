import BearLockCore
import DeviceActivity
import Foundation

protocol ScheduleControlling {
    func schedule(_ rule: LockRule) throws
    func cancel(_ rule: LockRule) throws
}

struct DeviceActivityScheduleController: ScheduleControlling {
    private let center = DeviceActivityCenter()
    private let calendar = Calendar.current

    func schedule(_ rule: LockRule) throws {
        try preserveActiveDeadline(for: rule)
        let name = DeviceActivityName(rule.deviceActivityName)
        let components = rule.monitoringComponents(calendar: calendar)
        let schedule = DeviceActivitySchedule(
            intervalStart: components.start,
            intervalEnd: components.end,
            repeats: rule.kind == .recurring
        )
        try center.startMonitoring(name, during: schedule)
    }

    func cancel(_ rule: LockRule) throws {
        try preserveActiveDeadline(for: rule)
        center.stopMonitoring([DeviceActivityName(rule.deviceActivityName)])
    }

    private func preserveActiveDeadline(for rule: LockRule) throws {
        let state = try JSONFileLockRepository(fileURL: AppGroup.lockStateURL).load()
        guard let active = state.activeLock, active.sourceRuleID == rule.id,
              active.isActive(at: Date()) else { return }
        // Replacing/stopping the parent monitor can emit an early end and remove its
        // natural end callback. Keep a separate one-shot monitor for this snapshot.
        let name = DeviceActivityName("bearlock.completion.\(active.id.uuidString)")
        guard !center.activities.contains(name) else { return }
        let snapshot = active.completionMonitoringRule
        let components = snapshot.monitoringComponents(calendar: calendar)
        try center.startMonitoring(name, during: DeviceActivitySchedule(
            intervalStart: components.start, intervalEnd: components.end, repeats: false
        ))
        DiagnosticsLogger.shared.record("Schedule.preservedActiveDeadline", detail: name.rawValue)
    }

}

extension LockRule {
    var deviceActivityName: String {
        "bearlock.\(id.uuidString)"
    }
}
