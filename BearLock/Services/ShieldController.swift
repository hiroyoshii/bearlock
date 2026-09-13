import BearLockCore
import FamilyControls
import Foundation
import ManagedSettings

protocol ShieldControlling: Sendable {
    /// An empty list removes Bear Lock's restriction; invalid selection data is an error.
    func applyShield(selections: [LockTargetSelectionRef]) throws
}

struct ManagedSettingsShieldController: ShieldControlling, @unchecked Sendable {
    private let store = ManagedSettingsStore(named: .bearLock)

    func applyShield(selections: [LockTargetSelectionRef]) throws {
        // A private-directory fallback must never be mistaken for empty shared state.
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            throw CocoaError(.fileReadNoPermission)
        }
        // Decode everything before changing settings, so corrupt data cannot partially apply.
        var combined = FamilyActivitySelection()
        for selection in selections {
            let selected = try selection.decodedSelection()
            combined.applicationTokens.formUnion(selected.applicationTokens)
            combined.categoryTokens.formUnion(selected.categoryTokens)
            combined.webDomainTokens.formUnion(selected.webDomainTokens)
        }
        if selections.isEmpty {
            store.clearAllSettings()
        } else {
            let apps = combined.applicationTokens.isEmpty ? nil : combined.applicationTokens
            let categories: ShieldSettings.ActivityCategoryPolicy<Application>? = combined.categoryTokens.isEmpty ? nil : .specific(combined.categoryTokens)
            let domains = combined.webDomainTokens.isEmpty ? nil : combined.webDomainTokens
            // Configuration callbacks may reconcile again. Do not rewrite unchanged settings.
            if store.shield.applications != apps { store.shield.applications = apps }
            if store.shield.applicationCategories != categories { store.shield.applicationCategories = categories }
            if store.shield.webDomains != domains { store.shield.webDomains = domains }
        }
        DiagnosticsLogger.shared.record(selections.isEmpty ? "Shield.clear.requested" : "Shield.apply.requested")
    }
}

extension ManagedSettingsStore.Name {
    static let bearLock = Self("bearlock.primary")
}
