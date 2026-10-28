import HarborKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// A temporary, minimal settings window. The Harbor hub will take these over
/// (see `settings-schema.json`), so everything here is a plain UserDefaults key.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            SwitcherSettings()
                .tabItem { Label("Switcher", systemImage: "rectangle.on.rectangle") }
            ExcludedAppsSettings()
                .tabItem { Label("Excluded Apps", systemImage: "eye.slash") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Prefs.panelStyle) private var panelStyle = "cream"
    @AppStorage(Prefs.accentColor) private var accentColor = "pebble"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var language = AppLanguage.current
    private let launchLanguage = AppLanguage.current
    private var permissions = Permissions.shared

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            }

            Section {
                Picker("Appearance", selection: $panelStyle) {
                    Text("Cream").tag("cream")
                    if #available(macOS 26, *) {
                        Text("Liquid Glass").tag("glass")
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("Highlight") {
                    AccentPicker(selection: $accentColor)
                }
                Text("How the switcher and Dock previews look.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: language) { _, language in language.apply() }
                if language != launchLanguage {
                    HStack {
                        Text("Restart Ferry to switch languages.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
            }

            Section("Permissions") {
                PermissionStatus(title: "Accessibility", granted: permissions.accessibility)
                PermissionStatus(title: "Screen Recording", granted: permissions.screenRecording)
                Button("Open Permissions…") { Onboarding.show() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionStatus: View {
    let title: LocalizedStringKey
    let granted: Bool

    var body: some View {
        LabeledContent(title) {
            Label(granted ? "Allowed" : "Not allowed",
                  systemImage: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? Color.primary : .secondary)
        }
    }
}

private struct SwitcherSettings: View {
    @AppStorage(Prefs.switcherModifier) private var modifier = "option"
    @AppStorage(Prefs.switcherSpaces) private var spaces = "all"
    @AppStorage(Prefs.switcherDisplays) private var displays = "all"
    @AppStorage(Prefs.switcherPlacement) private var placement = "mouse"
    @AppStorage(Prefs.showMinimized) private var showMinimized = true
    @AppStorage(Prefs.showHidden) private var showHidden = true
    @AppStorage(Prefs.dockPreviewsEnabled) private var dockPreviews = true
    @AppStorage(Prefs.dockPreviewDelay) private var dockDelay = 0.25

    var body: some View {
        Form {
            Section {
                Picker("Shortcut", selection: $modifier) {
                    Text("⌥ Option + Tab").tag("option")
                    Text("⌘ Command + Tab").tag("command")
                    Text("⌃ Control + Tab").tag("control")
                }
                if modifier == "command" {
                    Text("Ferry replaces the system’s ⌘Tab while it runs, and hands it back when you quit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Show on", selection: $placement) {
                    Text("Display with the pointer").tag("mouse")
                    Text("Display with the active window").tag("active")
                }
            }

            Section("Windows") {
                Picker("From", selection: $spaces) {
                    Text("All Spaces").tag("all")
                    Text("Current Space").tag("current")
                }
                Picker("Displays", selection: $displays) {
                    Text("All displays").tag("all")
                    Text("Only the display it opens on").tag("current")
                }
                Toggle("Include minimized windows", isOn: $showMinimized)
                Toggle("Include hidden apps", isOn: $showHidden)
            }

            Section("Dock") {
                Toggle(isOn: $dockPreviews) {
                    Text("Show windows when hovering a Dock icon")
                    Text("Ferry listens to the Dock itself, not to mouse movement.")
                }
                if dockPreviews {
                    LabeledContent("Delay") {
                        Slider(value: $dockDelay, in: 0...1, step: 0.05) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Instant")
                        } maximumValueLabel: {
                            Text("1 s")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ExcludedAppsSettings: View {
    @State private var apps: [String] = UserDefaults.standard.stringArray(forKey: Prefs.excludedApps) ?? []
    @State private var selection: String?

    var body: some View {
        Form {
            Section {
                if apps.isEmpty {
                    Text("Apps you add here never appear in the switcher or Dock previews.")
                        .foregroundStyle(.secondary)
                } else {
                    List(apps, id: \.self, selection: $selection) { id in
                        AppRow(bundleID: id)
                    }
                    .frame(minHeight: 160)
                }
            } footer: {
                HStack {
                    Button("Add App…", action: add)
                    Button("Remove", action: remove)
                        .disabled(selection == nil)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        apps = Array(Set(apps + ids)).sorted()
        save()
    }

    private func remove() {
        apps.removeAll { $0 == selection }
        selection = nil
        save()
    }

    private func save() {
        UserDefaults.standard.set(apps, forKey: Prefs.excludedApps)
    }
}

private struct AppRow: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack(spacing: 8) {
            Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application))
                .resizable()
                .frame(width: 20, height: 20)
            Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID)
        }
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .padding(.top, 24)
            Text("Ferry")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Text("Every window, one Tab away.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Link("kaandis.github.io/ferry", destination: URL(string: "https://kaandis.github.io/ferry/")!)
                .font(.callout)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }
}
