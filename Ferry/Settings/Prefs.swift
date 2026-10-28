import Foundation
import HarborKit

/// UserDefaults keys shared by @AppStorage and the services. Every key a user
/// can change is also described in `Resources/settings-schema.json` so the
/// Harbor hub can render these settings later.
enum Prefs {
    static let showMenuBarIcon = "showMenuBarIcon"
    /// Panel look: "cream" (Harbor's own) or "glass" (Liquid Glass, macOS 26+).
    static let panelStyle = "panelStyle"
    /// Selection colour: an `Accent` id ("pebble", "sky", "mint", "lilac", "sun", "coral", "graphite", "system").
    static let accentColor = "accentColor"
    /// The key held while pressing Tab: "option", "command" or "control".
    static let switcherModifier = "switcherModifier"
    /// "all" or "current" Space.
    static let switcherSpaces = "switcherSpaces"
    /// "all" displays or only the "current" one (where the switcher opens).
    static let switcherDisplays = "switcherDisplays"
    static let showMinimized = "showMinimized"
    static let showHidden = "showHidden"
    /// Where the switcher appears: "mouse" (display with the pointer) or "main".
    static let switcherPlacement = "switcherPlacement"
    static let dockPreviewsEnabled = "dockPreviewsEnabled"
    static let dockPreviewDelay = "dockPreviewDelay"
    /// Bundle identifiers Ferry leaves out of the switcher and Dock previews.
    static let excludedApps = "excludedApps"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            panelStyle: "cream",
            accentColor: "pebble",
            switcherModifier: "option",
            switcherSpaces: "all",
            switcherDisplays: "all",
            showMinimized: true,
            showHidden: true,
            switcherPlacement: "mouse",
            dockPreviewsEnabled: true,
            dockPreviewDelay: 0.25,
            excludedApps: [String](),
            hasCompletedOnboarding: false,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func string(_ key: String) -> String { UserDefaults.standard.string(forKey: key) ?? "" }
    static var excluded: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: excludedApps) ?? [])
    }
}
