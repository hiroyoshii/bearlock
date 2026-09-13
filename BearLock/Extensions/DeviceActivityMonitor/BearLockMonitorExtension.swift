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
            try LockLifecycle(repository: JSONFileLockRepository(fileURL: AppGroup.lockStateURL)).reconcile(
                apply: { try ManagedSettingsShieldController().applyShield(selections: $0) },
                record: { diagnostics.record("DeviceActivity.reconcile", detail: $0) })
            diagnostics.record("DeviceActivity.\(callback).finished")
        } catch {
            diagnostics.record("DeviceActivity.\(callback).failed", level: .error, detail: String(describing: error))
        }
    }
}
