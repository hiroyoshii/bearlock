import BearLockCore
import FamilyControls
import Foundation
import ManagedSettings

protocol ShieldControlling: Sendable {
    func reconcile(state: LockState, at date: Date) throws
}

struct ManagedSettingsShieldController: ShieldControlling, @unchecked Sendable {
    func reconcile(state: LockState, at date: Date = Date()) throws {
        // A private-directory fallback must never be mistaken for empty shared state.
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            throw CocoaError(.fileReadNoPermission)
        }

        let decisions = try state.shieldSlotDecisions(at: date)
        // Decode every active selection before changing any store.
        let decoded = try decisions.map { ($0.storeName, try $0.selection.decodedSelection()) }
        let activeNames = Set(decoded.map(\.0))
        let desiredNames = state.shieldStoreNames(at: date)
        var existingNames: Set<ManagedSettingsStore.Name> = []
        if #available(iOS 26.0, *) {
            existingNames.formUnion(ManagedSettingsStore.stores.filter { $0.rawValue.hasPrefix("bearlock.") })
        }

        for (name, selection) in decoded {
            apply(selection, to: ManagedSettingsStore(named: .init(name)))
        }
        for name in desiredNames where !activeNames.contains(name) {
            ManagedSettingsStore(named: .init(name)).clearAllSettings()
        }
        let orphanNames = Set(existingNames.filter { !desiredNames.contains($0.rawValue) })
        for name in orphanNames {
            ManagedSettingsStore(named: name).clearAllSettings()
        }
        if #available(iOS 26.0, *) {
            ManagedSettingsStore.deleteStores(orphanNames)
        }
    }

    /// A monitor callback only reconciles its own named store. Its start/end label is irrelevant.
    func reconcile(storeName: String, state: LockState, at date: Date = Date()) throws {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            throw CocoaError(.fileReadNoPermission)
        }
        let store = ManagedSettingsStore(named: .init(storeName))
        guard let decision = try state.shieldSlotDecision(named: storeName, at: date) else {
            store.clearAllSettings()
            return
        }
        apply(try decision.selection.decodedSelection(), to: store)
    }

    private func apply(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        let apps = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        let categories: ShieldSettings.ActivityCategoryPolicy<Application>? = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        let domains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        if store.shield.applications != apps { store.shield.applications = apps }
        if store.shield.applicationCategories != categories { store.shield.applicationCategories = categories }
        if store.shield.webDomains != domains { store.shield.webDomains = domains }
    }
}
