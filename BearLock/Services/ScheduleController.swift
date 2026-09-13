import BearLockCore
import DeviceActivity
import Foundation

protocol ScheduleControlling {
    func synchronize(_ rules: [LockRule], at now: Date) throws
}

struct DeviceActivityScheduleController: ScheduleControlling {
    private let center = DeviceActivityCenter()

    func synchronize(_ rules: [LockRule], at now: Date) throws {
        let existing = center.activities.compactMap { name -> MonitoringSchedule? in
            guard let schedule = center.schedule(for: name) else { return nil }
            return MonitoringSchedule(name: name.rawValue, start: schedule.intervalStart,
                end: schedule.intervalEnd, repeats: schedule.repeats)
        }
        try MonitoringSchedule.synchronize(desired: .desired(for: rules, at: now), existing: existing,
            start: { schedule in
                DiagnosticsLogger.shared.record("Schedule.register.begin", detail: schedule.name)
                try center.startMonitoring(DeviceActivityName(schedule.name), during: DeviceActivitySchedule(
                    intervalStart: schedule.start, intervalEnd: schedule.end, repeats: schedule.repeats))
                DiagnosticsLogger.shared.record("Schedule.register.returned", detail: schedule.name)
            }, stop: { name in
                center.stopMonitoring([DeviceActivityName(name)])
                DiagnosticsLogger.shared.record("Schedule.stop.returned", detail: name)
            })
    }
}
