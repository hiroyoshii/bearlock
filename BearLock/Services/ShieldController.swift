import BearLockCore
import FamilyControls
import Foundation
import ManagedSettings

protocol ShieldControlling {
    func applyShield(for activeLock: ActiveLock)
    func clearShield(for activeLock: ActiveLock)
}

struct ManagedSettingsShieldController: ShieldControlling {
    private let store = ManagedSettingsStore(named: .bearLock)
    private let selectionStore: TargetSelectionStoring

    init(selectionStore: TargetSelectionStoring) {
        self.selectionStore = selectionStore
    }

    func applyShield(for activeLock: ActiveLock) {
        guard let selection = try? selectionStore.load() else {
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    func clearShield(for activeLock: ActiveLock) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}

extension ManagedSettingsStore.Name {
    static let bearLock = Self("bearlock.primary")
}
