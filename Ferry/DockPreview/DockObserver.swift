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
    private var launchToken: NSObjectProtocol?

    func start() {
        attach()
        // The Dock restarts now and then (killall Dock, display changes); follow it.
        launchToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated { self?.attach() }
            }
        }
    }

    func stop() {
        detach()
        if let launchToken { NSWorkspace.shared.notificationCenter.removeObserver(launchToken) }
        launchToken = nil
    }

    private func attach() {
        detach()
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return }
        dockPID = dock.processIdentifier
        let app = AXUIElementCreateApplication(dockPID)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
              let list = (children as? [AXUIElement])?.first(where: { role(of: $0) == kAXListRole })
        else { return }

        var observer: AXObserver?
        guard AXObserverCreate(dockPID, dockCallback, &observer) == .success, let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString, refcon)
                == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
        self.list = list
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
        guard AXUIElementCopyAttributeValue(list, kAXSelectedChildrenAttribute as CFString, &selected) == .success,
              let item = (selected as? [AXUIElement])?.first,
              attribute(item, kAXSubroleAttribute) as? String == "AXApplicationDockItem",
              let url = attribute(item, kAXURLAttribute) as? URL
        else { return nil }
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath().path == path
        }) else { return nil }

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
