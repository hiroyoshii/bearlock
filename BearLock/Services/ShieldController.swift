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
    private let decoder = PropertyListDecoder()

    init(selectionStore: TargetSelectionStoring) {
        self.selectionStore = selectionStore
    }

    func applyShield(for activeLock: ActiveLock) {
        let selection: FamilyActivitySelection
        do {
            selection = try loadSelection(for: activeLock)
        } catch {
            diagnostics.record("Shield.apply.selectionLoad.failed", level: .error, detail: error.localizedDescription)
            return
        }

        let targetCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        guard targetCount > 0 else {
            diagnostics.record("Shield.apply.skippedEmptySelection", level: .warning)
            clearShield(for: activeLock)
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        diagnostics.record("Shield.apply.succeeded", detail: "active=\(activeLock.id.uuidString) targets=\(targetCount)")
    }

    func clearShield(for activeLock: ActiveLock) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        diagnostics.record("Shield.clear.succeeded", detail: activeLock.id.uuidString)
    }

    private func loadSelection(for activeLock: ActiveLock) throws -> FamilyActivitySelection {
        let state = try JSONFileLockRepository(fileURL: AppGroup.lockStateURL).load()
        if let selectionRef = state.targetSelections.last(where: { $0.id == activeLock.targetSelectionID }),
           let tokenData = selectionRef.tokenData {
            return try decoder.decode(FamilyActivitySelection.self, from: tokenData)
        }

        diagnostics.record("Shield.apply.fallbackToLatestSelection", level: .warning, detail: activeLock.targetSelectionID.uuidString)
        return try selectionStore.load()
    }
}

extension ManagedSettingsStore.Name {
    static let bearLock = Self("bearlock.primary")
}
