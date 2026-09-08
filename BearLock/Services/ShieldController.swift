import BearLockCore
import FamilyControls
import Foundation
import ManagedSettings

protocol ShieldControlling {
    func applyShield(for activeLock: ActiveLock, selection: LockTargetSelectionRef?) throws
    func clearShield()
}

struct ManagedSettingsShieldController: ShieldControlling {
    private let store = ManagedSettingsStore(named: .bearLock)
    private let diagnostics = DiagnosticsLogger.shared

    func applyShield(for activeLock: ActiveLock, selection: LockTargetSelectionRef?) throws {
        // Use tokens from the transaction's snapshot. Reading another repository here
        // would both race with selection changes and reenter the file lock.
        guard selection?.id == activeLock.targetSelectionID, let data = selection?.tokenData else {
            throw TargetSelectionStoreError.selectionDataUnavailable
        }
        let selected = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        let targetCount = selected.applicationTokens.count + selected.categoryTokens.count + selected.webDomainTokens.count
        guard targetCount > 0 else { throw TargetSelectionStoreError.emptySelection }

        store.shield.applications = selected.applicationTokens.isEmpty ? nil : selected.applicationTokens
        store.shield.applicationCategories = selected.categoryTokens.isEmpty ? nil : .specific(selected.categoryTokens)
        store.shield.webDomains = selected.webDomainTokens.isEmpty ? nil : selected.webDomainTokens
        diagnostics.record("Shield.apply.requested", detail: "active=\(activeLock.id) targets=\(targetCount)")
    }

    func clearShield() {
        store.clearAllSettings()
        // The API has no acknowledgement of enforcement on other apps.
        diagnostics.record("Shield.clear.requested")
    }
}

extension ManagedSettingsStore.Name {
    static let bearLock = Self("bearlock.primary")
}
