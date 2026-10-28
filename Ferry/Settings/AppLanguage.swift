import AppKit

/// In-app language override. macOS reads `AppleLanguages` at launch, so a
/// change takes effect after Ferry restarts.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    /// Shown in its own language so it's recognisable whatever is active.
    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    static var current: AppLanguage {
        guard let override = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String,
              UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] != nil
        else { return .system }
        return AppLanguage(rawValue: String(override.prefix(2))) ?? .system
    }

    func apply() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }

    /// The localization the app actually launched with — used for dates and
    /// numbers so they match the interface language.
    static var resolvedLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
