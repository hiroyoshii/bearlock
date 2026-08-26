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

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        Task {
            do {
                let store = try LockStore(repository: JSONFileLockRepository(fileURL: AppGroup.lockStateURL))
                let state = await store.snapshot()
                guard let rule = state.rules.first(where: { DeviceActivityName($0.deviceActivityName) == activity }) else {
                    return
                }

                let active = planner.activeLock(from: rule, intervalStart: Date())
                try await store.activate(active)
                shieldController.applyShield(for: active)
            } catch {
                assertionFailure("Failed to start Bear Lock interval: \(error)")
            }
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        Task {
            do {
                let store = try LockStore(repository: JSONFileLockRepository(fileURL: AppGroup.lockStateURL))
                if let completed = try await store.completeActiveLock(at: Date()) {
                    shieldController.clearShield(for: completed)
                }
            } catch {
                assertionFailure("Failed to end Bear Lock interval: \(error)")
            }
        }
    }
}
