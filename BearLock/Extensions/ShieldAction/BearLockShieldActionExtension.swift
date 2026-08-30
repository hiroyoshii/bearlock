import ManagedSettings
import ManagedSettingsUI

final class BearLockShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        DiagnosticsLogger.shared.record("ShieldAction.application", detail: action.diagnosticsText)
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        DiagnosticsLogger.shared.record("ShieldAction.webDomain", detail: action.diagnosticsText)
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        DiagnosticsLogger.shared.record("ShieldAction.category", detail: action.diagnosticsText)
        completionHandler(.close)
    }
}

private extension ShieldAction {
    var diagnosticsText: String {
        switch self {
        case .primaryButtonPressed:
            return "primaryButtonPressed"
        case .secondaryButtonPressed:
            return "secondaryButtonPressed"
        @unknown default:
            return "unknown"
        }
    }
}
