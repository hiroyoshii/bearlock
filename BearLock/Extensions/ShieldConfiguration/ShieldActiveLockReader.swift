import BearLockCore
import Foundation
import FamilyControls

struct ShieldActiveLockReader {
    func unlockText(state: LockState?, now: Date = Date(), matches: (FamilyActivitySelection) -> Bool) -> String? {
        guard let state else { return nil }
        let deadlines = state.activeLocks(at: now).compactMap { lock -> Date? in
            guard let ref = state.targetSelections.first(where: { $0.id == lock.targetSelectionID }),
                  let selection = try? ref.decodedSelection(), matches(selection) else { return nil }
            return state.wakeState.effectiveEnd(of: lock)
        }
        guard let endsAt = deadlines.max() else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = Calendar.current.isDate(endsAt, inSameDayAs: now) ? .none : .short
        formatter.timeStyle = .short
        return String(format: NSLocalizedString("Unlocks at %@", comment: ""), formatter.string(from: endsAt))
    }
}
