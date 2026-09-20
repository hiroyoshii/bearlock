import BearLockCore
import DeviceActivity
import Foundation

final class BearLockMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        handle(activity, callback: "intervalDidStart")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        handle(activity, callback: "intervalDidEnd")
    }

    private func handle(_ activity: DeviceActivityName, callback: String) {
        let diagnostics = DiagnosticsLogger.shared
        diagnostics.record("DeviceActivity.\(callback)", detail: activity.rawValue)
        guard activity.rawValue.hasPrefix("bearlock.") else { return }
        do {
            let state = try JSONFileLockRepository(fileURL: AppGroup.lockStateURL).load()
            let controller = ManagedSettingsShieldController()
            if activity.rawValue.hasPrefix("bearlock.wake.") {
                try controller.reconcile(state: state, at: Date())
            } else {
                try controller.reconcile(storeName: activity.rawValue, state: state, at: Date())
            }
            diagnostics.record("DeviceActivity.\(callback).finished")
        } catch {
            diagnostics.record("DeviceActivity.\(callback).failed", level: .error, detail: String(describing: error))
        }
    }
}
