import Foundation

enum AppLinks {
    private static var usesJapaneseSite: Bool {
        Bundle.main.preferredLocalizations.first == "ja"
    }

    static var privacyPolicy: URL {
        URL(string: usesJapaneseSite
            ? "https://bearlock.hiyozoo.com/privacy/"
            : "https://bearlock.hiyozoo.com/en/privacy/")!
    }

    static var support: URL {
        URL(string: usesJapaneseSite
            ? "https://bearlock.hiyozoo.com/support/"
            : "https://bearlock.hiyozoo.com/en/support/")!
    }
}
