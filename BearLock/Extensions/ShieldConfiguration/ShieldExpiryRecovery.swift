import BearLockCore
import Foundation

struct ShieldExpiryRecovery {
    func reconcile() -> LockState? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            DiagnosticsLogger.shared.record("ShieldRecovery.appGroupUnavailable", level: .error)
            return nil
        }
        do {
            let state = try JSONFileLockRepository(
                fileURL: containerURL.appendingPathComponent("lock-state.json")
            ).load()
            try ManagedSettingsShieldController().reconcile(state: state, at: Date())
            DiagnosticsLogger.shared.record("ShieldRecovery.reconcile")
            return state
        } catch {
            DiagnosticsLogger.shared.record("ShieldRecovery.failed", level: .error, detail: String(describing: error))
            return nil
        }
    }
}
