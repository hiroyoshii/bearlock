import BearLockCore
import FamilyControls
import Foundation

protocol TargetSelectionCoding {
    func reference(for selection: FamilyActivitySelection) throws -> LockTargetSelectionRef
    func selection(from reference: LockTargetSelectionRef?) throws -> FamilyActivitySelection
}

enum TargetSelectionStoreError: LocalizedError {
    case emptySelection
    case selectionDataUnavailable

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return L10n.string("No blocked apps are selected.")
        case .selectionDataUnavailable:
            return L10n.string("This saved target is no longer available.")
        }
    }
}

struct FamilyActivityTargetSelectionCodec: TargetSelectionCoding {
    func reference(for selection: FamilyActivitySelection) throws -> LockTargetSelectionRef {
        let count = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        guard count > 0 else { throw TargetSelectionStoreError.emptySelection }
        return LockTargetSelectionRef(displayName: L10n.format("%d targets", count),
            tokenData: try PropertyListEncoder().encode(selection))
    }

    func selection(from reference: LockTargetSelectionRef?) throws -> FamilyActivitySelection {
        guard let reference else { return FamilyActivitySelection() }
        return try reference.decodedSelection()
    }
}

// Shared by enforcement and the shield's deadline label.
extension LockTargetSelectionRef {
    func decodedSelection() throws -> FamilyActivitySelection {
        guard let data = tokenData else { throw TargetSelectionStoreError.selectionDataUnavailable }
        let selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else {
            throw TargetSelectionStoreError.emptySelection
        }
        return selection
    }
}
