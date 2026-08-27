import BearLockCore
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class BearLockMonitorExtension: DeviceActivityMonitor {
    private let planner = LockPlanner()
    private let shieldController = ManagedSettingsShieldController(
        selectionStore: FamilyActivityTargetSelectionStore()
    )
    private let diagnostics = DiagnosticsLogger.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        diagnostics.record("DeviceActivity.intervalDidStart", detail: String(describing: activity))

        Task {
            do {
                let store = try LockStore(repository: JSONFileLockRepository(fileURL: AppGroup.lockStateURL))
                let state = await store.snapshot()
                guard let rule = state.rules.first(where: { DeviceActivityName($0.deviceActivityName) == activity }) else {
                    diagnostics.record("DeviceActivity.ruleMissing", level: .warning, detail: String(describing: activity))
                    return
                }

                let active = planner.activeLock(from: rule, intervalStart: Date())
                try await store.activate(active)
                shieldController.applyShield(for: active)
                diagnostics.record("DeviceActivity.activeLockCreated", detail: rule.kind.rawValue)
            } catch {
                diagnostics.record("DeviceActivity.intervalDidStart.failed", level: .error, detail: error.localizedDescription)
                assertionFailure("Failed to start Bear Lock interval: \(error)")
            }
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        diagnostics.record("DeviceActivity.intervalDidEnd", detail: String(describing: activity))

        Task {
            do {
                let store = try LockStore(repository: JSONFileLockRepository(fileURL: AppGroup.lockStateURL))
                if let completed = try await store.completeActiveLock(at: Date()) {
                    shieldController.clearShield(for: completed)
                    diagnostics.record("DeviceActivity.activeLockCompleted", detail: completed.id.uuidString)
                }
            } catch {
                diagnostics.record("DeviceActivity.intervalDidEnd.failed", level: .error, detail: error.localizedDescription)
                assertionFailure("Failed to end Bear Lock interval: \(error)")
            }
        }
    }
}
