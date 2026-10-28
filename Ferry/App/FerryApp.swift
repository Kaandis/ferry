import HarborKit
import OSLog
import SwiftUI

let log = Logger(subsystem: "app.ferry.Ferry", category: "app")

@main
struct FerryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra("Ferry", systemImage: "ferry.fill", isInserted: $showMenuBarIcon) {
            MenuBarContent()
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarContent: View {
    private var permissions = Permissions.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if !permissions.accessibility {
            Button("Finish Setting Up…") { Onboarding.show() }
            Divider()
        }

        // With Harbor installed, settings live there; otherwise in Ferry's own window.
        Button("Settings…") {
            if !HarborLink.openSettings(appID: "ferry") {
                NSApp.activate()
                openSettings()
            }
        }
        .keyboardShortcut(",")

        Button("Permissions…") { Onboarding.show() }

        Divider()

        Button("Quit Ferry") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let switcher = SwitcherController()
    private let dockPreviews = DockPreviewController()
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        PreviewRenderer.runIfRequested()
        #endif
        Prefs.registerDefaults()
        SettingsBridge.listen()
        restoreCommandTabOnSignals()

        let permissions = Permissions.shared
        permissions.start()
        permissions.refresh()
        permissions.onAccessibilityGranted = { [weak self] in self?.startServices() }
        log.notice("Launched. accessibility=\(permissions.accessibility) screenRecording=\(permissions.screenRecording)")
        if permissions.accessibility { startServices() }
        if !permissions.accessibility || !Prefs.bool(Prefs.hasCompletedOnboarding) { Onboarding.show() }
    }

    private func startServices() {
        log.notice("Accessibility granted; starting window tracking, hotkey and Dock previews")
        WindowStore.shared.start()
        ThumbnailCache.shared.start()
        switcher.onActiveChange = { [weak self] active in self?.dockPreviews.setSuspended(active) }
        switcher.start()
        dockPreviews.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        switcher.stop()
    }

    /// If Ferry took over ⌘Tab, a plain `kill` must still hand it back.
    private func restoreCommandTabOnSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                PrivateAPI.setSystemCommandTab(enabled: true)
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    /// Opening the app again (Launchpad, Finder) shows Settings — the only way
    /// back in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        return true
    }
}
