import AppKit
import ApplicationServices

/// What Ferry can do to a window.
@MainActor
enum WindowActions {
    static func focus(_ item: WindowItem) {
        let element = WindowStore.shared.elements[item.id]
        let app = NSRunningApplication(processIdentifier: item.pid)
        if item.isAppHidden { app?.unhide() }
        if item.isMinimized, let element {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        // The SkyLight path also crosses Spaces; plain activation is the fallback.
        if !PrivateAPI.makeKeyAndFront(pid: item.pid, windowID: item.id) {
            app?.activate()
        }
        if let element {
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        }
        WindowStore.shared.bump(item.id, pid: item.pid)
    }

    static func close(_ item: WindowItem) {
        guard let element = WindowStore.shared.elements[item.id] else { return }
        var button: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &button) == .success,
           let button, CFGetTypeID(button) == AXUIElementGetTypeID() {
            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        }
    }

    static func minimize(_ item: WindowItem) {
        guard let element = WindowStore.shared.elements[item.id] else { return }
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString,
                                     item.isMinimized ? kCFBooleanFalse : kCFBooleanTrue)
    }

    static func quit(_ item: WindowItem) {
        NSRunningApplication(processIdentifier: item.pid)?.terminate()
    }

    static func hide(_ item: WindowItem) {
        guard let app = NSRunningApplication(processIdentifier: item.pid) else { return }
        _ = item.isAppHidden ? app.unhide() : app.hide()
    }
}
