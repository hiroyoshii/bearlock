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
        let name = DeviceActivityName(rule.deviceActivityName)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: rule.startsAt),
            intervalEnd: calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: rule.endsAt),
            repeats: rule.kind == .recurring
        )
        try center.startMonitoring(name, during: schedule)
    }

    func cancel(_ rule: LockRule) throws {
        center.stopMonitoring([DeviceActivityName(rule.deviceActivityName)])
    }
}

extension LockRule {
    var deviceActivityName: String {
        "bearlock.\(id.uuidString)"
    }
}
