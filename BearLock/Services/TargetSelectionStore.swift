import BearLockCore
import FamilyControls
import Foundation

protocol TargetSelectionStoring {
    func load() throws -> FamilyActivitySelection
    func save(_ selection: FamilyActivitySelection) throws -> LockTargetSelectionRef
}

enum TargetSelectionStoreError: LocalizedError {
    case emptySelection

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "ブロック対象アプリが選択されていません。"
        }
    }
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
        let count = selection.applicationTokens.count + selection.categoryTokens.count
        guard count > 0 else {
            throw TargetSelectionStoreError.emptySelection
        }

        let data = try encoder.encode(selection)
        try FileManager.default.createDirectory(at: AppGroup.containerURL, withIntermediateDirectories: true)
        try data.write(to: AppGroup.selectionURL, options: [.atomic])

        return LockTargetSelectionRef(
            displayName: "\(count) targets",
            tokenData: data
        )
    }
}
