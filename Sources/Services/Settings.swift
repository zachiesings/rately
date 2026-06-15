import SwiftUI

/// Lightweight, observable user preferences backed by `UserDefaults`.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var themeID: String {
        didSet { d.set(themeID, forKey: "rately.theme") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            d.set(launchAtLogin, forKey: "rately.launchAtLogin")
            LoginItem.setEnabled(launchAtLogin)
        }
    }
    /// Auto-refresh interval in minutes. Free tier is fixed at 10; Pro can change.
    @Published var refreshMinutes: Int {
        didSet { d.set(refreshMinutes, forKey: "rately.refreshMinutes") }
    }

    var theme: AppTheme { AppTheme(rawValue: themeID) ?? .aurora }

    private init() {
        themeID = d.string(forKey: "rately.theme") ?? AppTheme.aurora.rawValue
        launchAtLogin = LoginItem.isEnabled
        refreshMinutes = d.object(forKey: "rately.refreshMinutes") as? Int ?? 10
    }
}
