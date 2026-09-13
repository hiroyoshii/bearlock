import Foundation

public enum LockEvaluationError: Error {
    case missingSelection(UUID)
}

public extension LockState {
    /// Enforcement depends only on saved rules and current time.
    func selectionsToShield(at date: Date) throws -> [LockTargetSelectionRef] {
        try Set(activeLocks(at: date).map(\.targetSelectionID)).map { id in
            guard let selection = targetSelections.first(where: { $0.id == id }) else {
                throw LockEvaluationError.missingSelection(id)
            }
            return selection
        }
    }
}

public struct LockLifecycle {
    private let repository: LockRepository
    public init(repository: LockRepository) { self.repository = repository }

    /// Read/decide/apply is one transaction: an older decision must not clear a new lock.
    /// No history writes or callback identity checks. An empty selection means clear.
    @discardableResult
    public func reconcile(
        at date: Date? = nil,
        apply: ([LockTargetSelectionRef]) throws -> Void,
        record: (String) -> Void = { _ in }
    ) throws -> LockState {
        try repository.withExclusiveAccess {
            let state = try repository.load()
            let now = date ?? Date()
            let selections = try state.selectionsToShield(at: now)
            record("now=\(now.ISO8601Format()) selections=\(selections.map(\.id))")
            try apply(selections)
            record(selections.isEmpty ? "clear=requested" : "apply=requested")
            return state
        }
    }
}
