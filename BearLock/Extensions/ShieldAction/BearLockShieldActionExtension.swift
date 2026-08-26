import ManagedSettings
import ManagedSettingsUI

final class BearLockShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: Application,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.defer)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomain,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.defer)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategory,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.defer)
    }
}
