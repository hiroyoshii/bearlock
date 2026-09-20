import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class BearLockShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let activeLockReader = ShieldActiveLockReader()
    private let expiryRecovery = ShieldExpiryRecovery()

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return configuration(title: title(for: application.localizedDisplayName, fallbackKey: "This app is sleeping.")) { selection in
            application.token.map { selection.applicationTokens.contains($0) } ?? false
        }
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        let displayName = application.localizedDisplayName ?? category.localizedDisplayName
        return configuration(title: title(for: displayName, fallbackKey: "This app is sleeping.")) { selection in
            (application.token.map { selection.applicationTokens.contains($0) } ?? false) ||
            (category.token.map { selection.categoryTokens.contains($0) } ?? false)
        }
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return configuration(title: localized("This website is sleeping.")) { selection in
            webDomain.token.map { selection.webDomainTokens.contains($0) } ?? false
        }
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(title: title(for: category.localizedDisplayName, fallbackKey: "This website is sleeping.")) { selection in
            (webDomain.token.map { selection.webDomainTokens.contains($0) } ?? false) ||
            (category.token.map { selection.categoryTokens.contains($0) } ?? false)
        }
    }

    private func configuration(title: String, matches: (FamilyActivitySelection) -> Bool) -> ShieldConfiguration {
        let state = expiryRecovery.reconcile()
        let subtitle = activeLockReader.unlockText(state: state, matches: matches) ?? localized("Locked until the scheduled time.")

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: UIColor(red: 0.83, green: 0.90, blue: 0.97, alpha: 1.0),
            icon: UIImage(named: "ShieldBearVisualLocked") ?? UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: title,
                color: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 0.72)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: localized(primaryButtonKey),
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 1.0),
            secondaryButtonLabel: secondaryButtonLabel
        )
    }

    private var primaryButtonKey: String {
        if #available(iOS 26.0, *) { return "Wake the bear" }
        return "OK"
    }

    private var secondaryButtonLabel: ShieldConfiguration.Label? {
        guard #available(iOS 26.0, *) else { return nil }
        return ShieldConfiguration.Label(
            text: localized("Keep sleeping"),
            color: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 0.72)
        )
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: Bundle(for: Self.self), comment: "")
    }

    private func title(for displayName: String?, fallbackKey: String) -> String {
        guard let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty
        else {
            return localized(fallbackKey)
        }

        return String(format: localized("%@ is sleeping."), displayName)
    }
}
