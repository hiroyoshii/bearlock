import BearLockCore
import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import Foundation

final class BearLockShieldActionExtension: ShieldActionDelegate {
    private let allowanceMatcher = DailyAllowanceShieldMatcher()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        DiagnosticsLogger.shared.record("ShieldAction.application", detail: action.diagnosticsText)
        completionHandler(response(for: action) { $0.applicationTokens.contains(application) })
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        DiagnosticsLogger.shared.record("ShieldAction.webDomain", detail: action.diagnosticsText)
        completionHandler(response(for: action) { $0.webDomainTokens.contains(webDomain) })
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        DiagnosticsLogger.shared.record("ShieldAction.category", detail: action.diagnosticsText)
        completionHandler(response(for: action) { $0.categoryTokens.contains(category) })
    }

    private func response(
        for action: ShieldAction,
        matches: (FamilyActivitySelection) -> Bool
    ) -> ShieldActionResponse {
        guard action == .primaryButtonPressed else { return .close }
        if #available(iOS 26.5, *) {
            let destination: ShieldLaunchDestination = isDailyAllowanceShield(matches: matches) ? .dailyAllowance : .wake
            ShieldLaunchRequest.record(destination)
            return .openParentalControlsApp
        }
        return .close
    }

    private func isDailyAllowanceShield(matches: (FamilyActivitySelection) -> Bool) -> Bool {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier),
              let state = try? JSONFileLockRepository(fileURL: containerURL.appendingPathComponent("lock-state.json")).load()
        else { return false }
        return allowanceMatcher.isDailyAllowanceOnly(state: state, matches: matches)
    }
}

private extension ShieldAction {
    var diagnosticsText: String {
        switch self {
        case .primaryButtonPressed:
            return "primaryButtonPressed"
        case .secondaryButtonPressed:
            return "secondaryButtonPressed"
        default:
            return "unknown"
        }
    }
}
