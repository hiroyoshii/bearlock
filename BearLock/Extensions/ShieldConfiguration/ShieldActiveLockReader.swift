import Foundation

struct ShieldActiveLockReader {
    private let appGroupIdentifier = "group.com.hiyozoo.bearlock"
    private let fileName = "lock-state.json"

    func unlockText(now: Date = Date()) -> String? {
        guard let activeLock = activeLock(now: now) else {
            ShieldConfigurationDiagnostics.recordOnce("ShieldConfiguration.activeLock.missing")
            return nil
        }

        let text = String(
            format: localized("Unlocks at %@"),
            formattedUnlockTime(activeLock.endsAt)
        )
        ShieldConfigurationDiagnostics.recordOnce(
            "ShieldConfiguration.activeLock.loaded",
            detail: activeLock.endsAt.ISO8601Format()
        )
        return text
    }

    private func activeLock(now: Date) -> ShieldActiveLock? {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = containerURL.appending(path: fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(ShieldLockState.self, from: Data(contentsOf: url))
            guard let activeLock = state.activeLock, activeLock.isActive(at: now) else {
                return nil
            }
            return activeLock
        } catch {
            ShieldConfigurationDiagnostics.recordOnce(
                "ShieldConfiguration.activeLock.readFailed",
                detail: error.localizedDescription
            )
            return nil
        }
    }

    private func formattedUnlockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: Bundle(for: BearLockShieldConfigurationExtension.self), comment: "")
    }
}

private struct ShieldLockState: Decodable {
    var activeLock: ShieldActiveLock?
}

private struct ShieldActiveLock: Decodable {
    var startedAt: Date
    var endsAt: Date

    func isActive(at date: Date) -> Bool {
        startedAt <= date && date < endsAt
    }
}
