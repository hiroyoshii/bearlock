import BearLockCore
import Foundation

struct ShieldExpiryRecovery {
    func reconcile() -> LockState? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            DiagnosticsLogger.shared.record("ShieldRecovery.appGroupUnavailable", level: .error)
            return nil
        }
        do {
            return try LockLifecycle(repository: JSONFileLockRepository(
                fileURL: containerURL.appendingPathComponent("lock-state.json"))).reconcile(
                    apply: { try ManagedSettingsShieldController().applyShield(selections: $0) },
                    record: { DiagnosticsLogger.shared.record("ShieldRecovery.reconcile", detail: $0) })
        } catch {
            DiagnosticsLogger.shared.record("ShieldRecovery.failed", level: .error, detail: String(describing: error))
            return nil
        }
    }
}
