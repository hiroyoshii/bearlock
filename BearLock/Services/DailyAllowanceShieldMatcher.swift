import BearLockCore
import FamilyControls
import Foundation

struct DailyAllowanceShieldMatcher {
    func isDailyAllowanceOnly(
        state: LockState?,
        at date: Date = Date(),
        matches: (FamilyActivitySelection) -> Bool
    ) -> Bool {
        guard let state,
              let target = state.dailyAllowance.shieldTarget(at: date),
              let selection = try? target.decodedSelection(),
              matches(selection)
        else { return false }

        return !state.activeLocks(at: date).contains { lock in
            guard let ref = state.targetSelections.last(where: { $0.id == lock.targetSelectionID }),
                  let activeSelection = try? ref.decodedSelection()
            else { return false }
            return matches(activeSelection)
        }
    }
}
