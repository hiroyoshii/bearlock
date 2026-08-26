import BearLockCore
import FamilyControls
import Foundation

protocol TargetSelectionStoring {
    func load() throws -> FamilyActivitySelection
    func save(_ selection: FamilyActivitySelection) throws -> LockTargetSelectionRef
}

struct FamilyActivityTargetSelectionStore: TargetSelectionStoring {
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()

    func load() throws -> FamilyActivitySelection {
        guard FileManager.default.fileExists(atPath: AppGroup.selectionURL.path) else {
            return FamilyActivitySelection()
        }

        let data = try Data(contentsOf: AppGroup.selectionURL)
        return try decoder.decode(FamilyActivitySelection.self, from: data)
    }

    func save(_ selection: FamilyActivitySelection) throws -> LockTargetSelectionRef {
        let data = try encoder.encode(selection)
        try FileManager.default.createDirectory(at: AppGroup.containerURL, withIntermediateDirectories: true)
        try data.write(to: AppGroup.selectionURL, options: [.atomic])

        let count = selection.applicationTokens.count + selection.categoryTokens.count
        return LockTargetSelectionRef(
            displayName: count == 0 ? "No apps selected" : "\(count) targets",
            tokenData: data
        )
    }
}
