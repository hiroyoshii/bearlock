import ManagedSettings
import ManagedSettingsUI
import UIKit

final class BearLockShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    private func configuration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: UIColor(red: 0.83, green: 0.90, blue: 0.97, alpha: 1.0),
            icon: UIImage(named: "ShieldBrandDen") ?? UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "Bear is sleeping.",
                color: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Do not wake the bear.",
                color: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 0.72)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Come back later",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.08, green: 0.18, blue: 0.31, alpha: 1.0)
        )
    }
}
