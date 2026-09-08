import BearLockCore
import DeviceActivity
import Foundation

final class BearLockMonitorExtension: DeviceActivityMonitor {
    private let shieldController = ManagedSettingsShieldController()
    private let diagnostics = DiagnosticsLogger.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        handle(activity, starting: true)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        handle(activity, starting: false)
    }

    private func handle(_ activity: DeviceActivityName, starting: Bool) {
        let callback = starting ? "intervalDidStart" : "intervalDidEnd"
        diagnostics.record("DeviceActivity.\(callback)", detail: activity.rawValue)
        do {
            let repository = JSONFileLockRepository(fileURL: AppGroup.lockStateURL)
            let ruleID: UUID
            let completionID: UUID?
            if activity.rawValue.hasPrefix("bearlock.completion.") {
                // This monitor only preserves an active occurrence's end when its parent
                // is edited/stopped. Its immediate start callback must not activate anything.
                guard !starting,
                      let activeID = UUID(uuidString: String(activity.rawValue.dropFirst("bearlock.completion.".count))) else { return }
                let state = try repository.load()
                let snapshot = state.activeLock?.id == activeID ? state.activeLock : state.completedLocks.first { $0.id == activeID }
                guard let source = snapshot?.sourceRuleID else {
                    diagnostics.record("DeviceActivity.unknownCompletion", level: .warning, detail: activity.rawValue)
                    return
                }
                ruleID = source
                completionID = activeID
            } else {
                guard activity.rawValue.hasPrefix("bearlock."),
                      let source = UUID(uuidString: String(activity.rawValue.dropFirst("bearlock.".count))) else {
                    diagnostics.record("DeviceActivity.unknownActivity", level: .warning, detail: activity.rawValue)
                    return
                }
                ruleID = source
                completionID = nil
            }
            // No unstructured Task: finish reconciliation before returning to the OS.
            try LockLifecycle(repository: repository).reconcile(
                event: starting ? .intervalStarted(ruleID: ruleID) : .intervalEnded(ruleID: ruleID, activeID: completionID),
                at: Date(),
                apply: { try self.shieldController.applyShield(for: $0, selection: $1) },
                clear: { self.shieldController.clearShield() },
                record: { self.diagnostics.record("DeviceActivity.reconcile", detail: $0) }
            )
            diagnostics.record("DeviceActivity.\(callback).finished")
        } catch {
            diagnostics.record("DeviceActivity.\(callback).failed", level: .error, detail: String(describing: error))
        }
    }
}
