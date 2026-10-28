import AppKit
import ApplicationServices

/// Knows which windows exist and in which order they were last used.
///
/// Nothing here runs on a timer. The window list is built when the switcher or
/// a Dock preview asks for it, and the recency order is kept current by
/// Accessibility notifications that fire only when focus actually changes.
@MainActor
final class WindowStore {
    static let shared = WindowStore()

    struct Options {
        var allSpaces = true
        /// Only windows whose centre lies on this display (Quartz coordinates).
        var display: CGRect?
        var includeMinimized = true
        var includeHidden = true
        var excludedBundleIDs: Set<String> = []
        var onlyPID: pid_t?
        /// Walk Accessibility tokens to confirm untitled windows on other Spaces.
        /// Only the switcher needs this; picture refreshes skip it.
        var lookUpOtherSpaces = true
    }

    private final class TrackedApp {
        let app: NSRunningApplication
        let element: AXUIElement
        var observer: AXObserver?
        /// Windows on other Spaces found by token lookup. Cached until the app
        /// creates a window, because the lookup costs about a thousand IPCs.
        var tokenWindows: [CGWindowID: AXUIElement]?
        var lastTokenLookup = Date.distantPast

        init(app: NSRunningApplication) {
            self.app = app
            element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.25)
        }
    }

    private var apps: [pid_t: TrackedApp] = [:]
    private var recent: [CGWindowID] = []
    private var recentOwners: [CGWindowID: pid_t] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private let queue = DispatchQueue(label: "app.ferry.windows", qos: .userInteractive)
    private(set) var isStarted = false

    /// Accessibility elements from the latest snapshot, for focusing and closing.
    private(set) var elements: [CGWindowID: AXUIElement] = [:]

    // MARK: Lifecycle

    func start() {
        guard !isStarted, AXIsProcessTrusted() else { return }
        isStarted = true
        NSWorkspace.shared.runningApplications.forEach(track)
        if let front = NSWorkspace.shared.frontmostApplication { noteActivation(of: front) }

        let center = NSWorkspace.shared.notificationCenter
        func on(_ name: Notification.Name, _ body: @escaping @MainActor (NSRunningApplication) -> Void) {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated { body(app) }
            })
        }
        on(NSWorkspace.didLaunchApplicationNotification) { [weak self] app in
            self?.track(app)
            // A freshly launched app often isn't ready for observers yet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.attachObserver(to: app.processIdentifier) }
        }
        on(NSWorkspace.didTerminateApplicationNotification) { [weak self] app in self?.untrack(app.processIdentifier) }
        on(NSWorkspace.didActivateApplicationNotification) { [weak self] app in self?.noteActivation(of: app) }
    }

    private func track(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != getpid(), apps[pid] == nil else { return }
        apps[pid] = TrackedApp(app: app)
        attachObserver(to: pid)
    }

    private func attachObserver(to pid: pid_t) {
        guard let tracked = apps[pid], tracked.observer == nil else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, observerCallback, &observer) == .success, let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let focused = AXObserverAddNotification(observer, tracked.element, kAXFocusedWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(observer, tracked.element, kAXWindowCreatedNotification as CFString, refcon)
        guard focused == .success || focused == .notificationAlreadyRegistered else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        tracked.observer = observer
    }

    /// Drops everything about a quit app at once, so nothing piles up over weeks of uptime.
    private func untrack(_ pid: pid_t) {
        if let observer = apps[pid]?.observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        apps[pid] = nil
        AppIcons.forget(pid)
        let gone = Set(recentOwners.filter { $0.value == pid }.keys)
        recent.removeAll { gone.contains($0) }
        gone.forEach { recentOwners[$0] = nil; elements[$0] = nil }
    }

    fileprivate func handle(_ notification: String, element: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        switch notification {
        case kAXFocusedWindowChangedNotification:
            if let id = PrivateAPI.windowID(of: element) { bump(id, pid: pid) }
        case kAXWindowCreatedNotification:
            apps[pid]?.tokenWindows = nil
        default:
            break
        }
    }

    private func noteActivation(of app: NSRunningApplication) {
        guard let tracked = apps[app.processIdentifier] else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(tracked.element, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID(),
              let id = PrivateAPI.windowID(of: value as! AXUIElement) else { return }
        bump(id, pid: app.processIdentifier)
    }

    func bump(_ id: CGWindowID, pid: pid_t) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        recentOwners[id] = pid
        if recent.count > 300, let last = recent.popLast() { recentOwners[last] = nil }
    }

    // MARK: Snapshot

    /// Builds the window list off the main thread and calls `update` on the
    /// main thread. `update` may run a second time once windows on other
    /// Spaces have been looked up.
    func snapshot(_ options: Options, update: @escaping @MainActor ([WindowItem]) -> Void) {
        guard isStarted else { update([]); return }
        let inputs = apps.values
            .filter { options.onlyPID == nil || $0.app.processIdentifier == options.onlyPID }
            .filter { !options.excludedBundleIDs.contains($0.app.bundleIdentifier ?? "") }
            .map { AppInput(pid: $0.app.processIdentifier, element: $0.element, bundleID: $0.app.bundleIdentifier,
                            name: $0.app.localizedName ?? "", isHidden: $0.app.isHidden, tokenWindows: $0.tokenWindows) }
        let rank = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

        queue.async {
            let result = Self.collect(inputs, rank: rank, options: options)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.elements.merge(result.elements) { _, new in new }
                    update(result.items)
                    // At most one walk per app a minute, however often it opens windows.
                    let due = result.needsTokenLookup.filter {
                        (self.apps[$0]?.lastTokenLookup.timeIntervalSinceNow ?? 0) < -60
                    }
                    guard options.lookUpOtherSpaces, !due.isEmpty else { return }
                    due.forEach { self.apps[$0]?.lastTokenLookup = Date() }
                    self.lookUpOtherSpaces(due) { self.snapshot(options, update: update) }
                }
            }
        }
    }

    private func lookUpOtherSpaces(_ pids: Set<pid_t>, then: @escaping @MainActor () -> Void) {
        queue.async {
            var found: [pid_t: [CGWindowID: AXUIElement]] = [:]
            for pid in pids {
                var map: [CGWindowID: AXUIElement] = [:]
                for element in PrivateAPI.windowsByToken(pid: pid) {
                    if let id = PrivateAPI.windowID(of: element) { map[id] = element }
                }
                found[pid] = map
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    for (pid, map) in found { self.apps[pid]?.tokenWindows = map }
                    then()
                }
            }
        }
    }

    private struct AppInput: @unchecked Sendable {
        let pid: pid_t
        let element: AXUIElement
        let bundleID: String?
        let name: String
        let isHidden: Bool
        let tokenWindows: [CGWindowID: AXUIElement]?
    }

    private struct AXWindow {
        let element: AXUIElement
        let title: String
        let subrole: String
        let minimized: Bool
        let fullScreen: Bool
    }

    private struct Collected: @unchecked Sendable {
        var items: [WindowItem] = []
        var elements: [CGWindowID: AXUIElement] = [:]
        var needsTokenLookup: Set<pid_t> = []
    }

    nonisolated private static func describe(_ element: AXUIElement) -> AXWindow {
        let names = [kAXTitleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, "AXFullScreen"] as CFArray
        var values: CFArray?
        AXUIElementCopyMultipleAttributeValues(element, names, AXCopyMultipleAttributeOptions(), &values)
        let list = values as? [Any] ?? []
        func value(_ i: Int) -> Any? { i < list.count ? list[i] : nil }
        return AXWindow(element: element,
                        title: value(0) as? String ?? "",
                        subrole: value(1) as? String ?? "",
                        minimized: value(2) as? Bool ?? false,
                        fullScreen: value(3) as? Bool ?? false)
    }

    nonisolated private static func collect(_ inputs: [AppInput], rank: [CGWindowID: Int], options: Options) -> Collected {
        var out = Collected()
        let byPID = Dictionary(inputs.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return out }

        // Accessibility details for windows on the current Space (and minimized ones).
        var ax: [CGWindowID: AXWindow] = [:]
        let pidsWithWindows = Set(list.compactMap { entry -> pid_t? in
            guard entry[kCGWindowLayer as String] as? Int == 0 else { return nil }
            return entry[kCGWindowOwnerPID as String] as? pid_t
        })
        for pid in pidsWithWindows {
            guard let app = byPID[pid] else { continue }
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(app.element, kAXWindowsAttribute as CFString, &value) == .success,
               let windows = value as? [AXUIElement] {
                for element in windows {
                    if let id = PrivateAPI.windowID(of: element) { ax[id] = describe(element) }
                }
            }
        }

        let spaces = PrivateAPI.spaceInfo()
        // Windows Accessibility didn't list must prove they're really shown somewhere.
        let unlisted = list.compactMap { entry -> CGWindowID? in
            guard entry[kCGWindowLayer as String] as? Int == 0,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID, ax[id] == nil else { return nil }
            return id
        }
        let orderedIn = PrivateAPI.orderedIn(unlisted)
        var order = 0
        var ranked: [(Int, WindowItem)] = []
        for entry in list {
            guard entry[kCGWindowLayer as String] as? Int == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, let app = byPID[pid],
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict),
                  frame.width >= 60, frame.height >= 40,
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0
            else { continue }
            let onScreen = entry[kCGWindowIsOnscreen as String] as? Bool ?? false
            let windowSpaces = PrivateAPI.spaces(for: id)

            var info = ax[id]
            if info == nil {
                // Not in the app's list: on another Space, or not a real window at all.
                guard !windowSpaces.isEmpty, windowSpaces.allSatisfy({ !spaces.visible.contains($0) }),
                      orderedIn?.contains(id) ?? true else { continue }
                if let element = app.tokenWindows?[id] {
                    info = describe(element)
                } else {
                    // The token walk only reaches the first thousand elements, so a
                    // long-running app's windows can be missing from it. A window
                    // with a title, on a desktop Space, is trusted as it is.
                    if app.tokenWindows == nil { out.needsTokenLookup.insert(pid) }
                    let title = entry[kCGWindowName as String] as? String ?? ""
                    guard !title.isEmpty else { continue }
                    var item = WindowItem(id: id, pid: pid, bundleID: app.bundleID, appName: app.name, title: title, frame: frame)
                    item.isOnScreen = false
                    item.isConfirmed = false
                    item.otherSpace = windowSpaces.compactMap { spaces.numbers[$0] }.first
                    item.isFullScreen = windowSpaces.contains { spaces.fullScreen.contains($0) }
                    item.isAppHidden = app.isHidden
                    ranked.append((rank[id] ?? 10_000 + order, item))
                    order += 1
                    continue
                }
            }
            guard let info, ["AXStandardWindow", "AXDialog"].contains(info.subrole) || info.fullScreen else { continue }

            var item = WindowItem(id: id, pid: pid, bundleID: app.bundleID, appName: app.name,
                                  title: info.title, frame: frame)
            item.isMinimized = info.minimized
            item.isAppHidden = app.isHidden
            item.isOnScreen = onScreen
            item.isFullScreen = info.fullScreen || windowSpaces.contains { spaces.fullScreen.contains($0) }
            let elsewhere = !windowSpaces.isEmpty && windowSpaces.allSatisfy { !spaces.visible.contains($0) }
            if elsewhere && !info.minimized {
                item.otherSpace = windowSpaces.compactMap { spaces.numbers[$0] }.first
            }
            out.elements[id] = info.element
            ranked.append((rank[id] ?? 10_000 + order, item))
            order += 1
        }

        out.items = ranked
            .sorted { $0.0 < $1.0 }
            .map(\.1)
            .filter { item in
                if !options.includeMinimized && item.isMinimized { return false }
                if !options.includeHidden && item.isAppHidden { return false }
                if !options.allSpaces && (item.otherSpace != nil || (item.isFullScreen && !item.isOnScreen)) { return false }
                if let display = options.display, !display.contains(CGPoint(x: item.frame.midX, y: item.frame.midY)) {
                    return false
                }
                return true
            }
        return out
    }
}

private func observerCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
                              _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let store = Unmanaged<WindowStore>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated { store.handle(name, element: element) }
}
