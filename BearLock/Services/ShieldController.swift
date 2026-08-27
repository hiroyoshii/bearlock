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
    private let diagnostics = DiagnosticsLogger.shared

    init(selectionStore: TargetSelectionStoring) {
        self.selectionStore = selectionStore
    }

    func applyShield(for activeLock: ActiveLock) {
        let selection: FamilyActivitySelection
        do {
            selection = try selectionStore.load()
        } catch {
            diagnostics.record("Shield.apply.selectionLoad.failed", level: .error, detail: error.localizedDescription)
            return
        }

        let targetCount = selection.applicationTokens.count + selection.categoryTokens.count
        guard targetCount > 0 else {
            diagnostics.record("Shield.apply.skippedEmptySelection", level: .warning)
            clearShield(for: activeLock)
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        diagnostics.record("Shield.apply.succeeded", detail: "\(targetCount) targets")
    }

    func clearShield(for activeLock: ActiveLock) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        diagnostics.record("Shield.clear.succeeded", detail: activeLock.id.uuidString)
    }
}

extension ManagedSettingsStore.Name {
    static let bearLock = Self("bearlock.primary")
}
