import AppKit

/// One window as the switcher and Dock previews show it.
struct WindowItem: Identifiable, Equatable {
    let id: CGWindowID
    let pid: pid_t
    let bundleID: String?
    let appName: String
    var title: String
    /// Global frame in Quartz coordinates (origin at the top-left of the main display).
    var frame: CGRect
    var isMinimized = false
    var isAppHidden = false
    var isFullScreen = false
    /// Mission Control number of the Space it lives on, when that isn't a Space on screen now.
    var otherSpace: Int?
    var isOnScreen = true
    /// Whether Accessibility vouched for this window (it has an AX element).
    var isConfirmed = true

    /// What the tile's caption says: the window title, or the app name for untitled windows.
    var displayTitle: String { title.isEmpty ? appName : title }
}

/// Looks up and caches app icons; `NSRunningApplication.icon` decodes on every call.
@MainActor
enum AppIcons {
    private static var cache: [pid_t: NSImage] = [:]
    static var overrides: [pid_t: NSImage] = [:]

    static func icon(for pid: pid_t) -> NSImage {
        if let image = overrides[pid] ?? cache[pid] { return image }
        let image = NSRunningApplication(processIdentifier: pid)?.icon
            ?? NSWorkspace.shared.icon(for: .application)
        cache[pid] = image
        return image
    }

    static func forget(_ pid: pid_t) { cache[pid] = nil }
}
