import BearLockCore
import FamilyControls
import Foundation
import ManagedSettings

/// The shield UI is another system-managed execution point. Use it to recover a
/// restriction whose DeviceActivity end callback has not reconciled yet.
struct ShieldExpiryRecovery {
    private let appGroupIdentifier = "group.com.hiyozoo.bearlock"
    private let fileName = "lock-state.json"
    private let store = ManagedSettingsStore(named: Self.storeName)

    func reconcile(now: Date = Date()) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            ShieldConfigurationDiagnostics.record("ShieldRecovery.appGroupUnavailable")
            return
        }

        let repository = JSONFileLockRepository(fileURL: containerURL.appendingPathComponent(fileName))
        do {
            try LockLifecycle(repository: repository).reconcile(
                event: .shieldPresented,
                at: now,
                apply: applyShield,
                clear: clearShield,
                record: { ShieldConfigurationDiagnostics.record("ShieldRecovery.reconcile", detail: $0) }
            )
            ShieldConfigurationDiagnostics.record("ShieldRecovery.finished")
        } catch {
            ShieldConfigurationDiagnostics.record(
                "ShieldRecovery.failed",
                detail: String(describing: error)
            )
        }
    }

    private func applyShield(for activeLock: ActiveLock, selection: LockTargetSelectionRef?) throws {
        guard selection?.id == activeLock.targetSelectionID, let data = selection?.tokenData else {
            throw ShieldExpiryRecoveryError.selectionDataUnavailable
        }

        let selected = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        store.shield.applications = selected.applicationTokens.isEmpty ? nil : selected.applicationTokens
        store.shield.applicationCategories = selected.categoryTokens.isEmpty ? nil : .specific(selected.categoryTokens)
        store.shield.webDomains = selected.webDomainTokens.isEmpty ? nil : selected.webDomainTokens
        ShieldConfigurationDiagnostics.record("ShieldRecovery.apply", detail: activeLock.id.uuidString)
    }

    private func clearShield() {
        store.clearAllSettings()
        ShieldConfigurationDiagnostics.record("ShieldRecovery.clear")
    }

    private static let storeName = ManagedSettingsStore.Name("bearlock.primary")
}

private enum ShieldExpiryRecoveryError: Error {
    case selectionDataUnavailable
}
