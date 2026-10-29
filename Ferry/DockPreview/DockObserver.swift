import AppKit
import ApplicationServices

/// Reports which Dock icon is under the pointer by listening to the Dock's own
/// Accessibility selection, which changes as you hover. No mouse monitoring:
/// Ferry hears about the Dock only when you're actually on it.
@MainActor
final class DockObserver {
    struct Hover: Equatable {
        let app: NSRunningApplication
        /// The icon's frame in Quartz coordinates.
        let iconFrame: CGRect
    }

    var onChange: ((Hover?) -> Void)?

    private var observer: AXObserver?
    private var list: AXUIElement?
    private var dockPID: pid_t = 0
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var retry: DispatchWorkItem?

    func start() {
        attachSoon()
        // The Dock restarts now and then (killall Dock), and rebuilds its icon
        // list when displays change or the Mac wakes; the old list then stops
        // reporting. Attach again each time.
        let workspace = NSWorkspace.shared.notificationCenter
        tokens.append((workspace, workspace.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            MainActor.assumeIsolated { self?.attachSoon(after: 1) }
        }))
        tokens.append((workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.attachSoon(after: 2) }
        }))
        tokens.append((NotificationCenter.default, NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.attachSoon(after: 1) }
        }))
    }

    func stop() {
        retry?.cancel()
        detach()
        tokens.forEach { $0.0.removeObserver($0.1) }
        tokens.removeAll()
    }

    /// Attaches now (or after `delay`), trying again a few times while the
    /// Dock is still starting up.
    private func attachSoon(after delay: TimeInterval = 0, attempt: Int = 0) {
        retry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.attach(), attempt < 4 else { return }
            self.attachSoon(after: [1, 2, 4, 8][attempt], attempt: attempt + 1)
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    @discardableResult
    private func attach() -> Bool {
        detach()
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return false }
        dockPID = dock.processIdentifier
        let app = AXUIElementCreateApplication(dockPID)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
              let list = (children as? [AXUIElement])?.first(where: { role(of: $0) == kAXListRole })
        else { return false }

        var observer: AXObserver?
        guard AXObserverCreate(dockPID, dockCallback, &observer) == .success, let observer else { return false }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString, refcon)
                == .success else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
        self.list = list
        return true
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        list = nil
    }

    /// The Dock's icon strip in Quartz coordinates, read on demand.
    var dockFrame: CGRect? {
        guard let list else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let position = attribute(list, kAXPositionAttribute), CFGetTypeID(position as CFTypeRef) == AXValueGetTypeID(),
              let extent = attribute(list, kAXSizeAttribute), CFGetTypeID(extent as CFTypeRef) == AXValueGetTypeID()
        else { return nil }
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(extent as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    fileprivate func selectionChanged() {
        onChange?(currentHover())
    }

    private func currentHover() -> Hover? {
        guard let list else { return nil }
        var selected: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(list, kAXSelectedChildrenAttribute as CFString, &selected)
        if result == .invalidUIElement {
            // The Dock rebuilt its list under us.
            attachSoon()
            return nil
        }
        guard result == .success,
              let item = (selected as? [AXUIElement])?.first,
              attribute(item, kAXSubroleAttribute) as? String == "AXApplicationDockItem",
              let url = attribute(item, kAXURLAttribute) as? URL
        else { return nil }
        // Match by location, or by bundle id when the Dock's copy and the
        // running one sit at different paths.
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let running = NSWorkspace.shared.runningApplications
        let bundleID = Bundle(url: url)?.bundleIdentifier
        guard let app = running.first(where: { $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath().path == path })
                ?? running.first(where: { bundleID != nil && $0.bundleIdentifier == bundleID && $0.activationPolicy == .regular })
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        if let value = attribute(item, kAXPositionAttribute), CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgPoint, &origin)
        }
        if let value = attribute(item, kAXSizeAttribute), CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgSize, &size)
        }
        return Hover(app: app, iconFrame: CGRect(origin: origin, size: size))
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func role(of element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute) as? String
    }
}

private func dockCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
                          _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let dock = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated { dock.selectionChanged() }
}
