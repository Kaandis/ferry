import AppKit

/// `Ferry --list-windows` prints every window Ferry sees, whether the
/// switcher keeps it and why, then exits. For working out why a window
/// doesn't show up; it changes nothing.
@MainActor
enum Diagnostics {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--list-windows") else { return false }
        print("Accessibility: \(AXIsProcessTrusted()), Screen Recording: \(CGPreflightScreenCaptureAccess())")
        WindowStore.shared.start()
        var options = WindowStore.Options()
        options.trace = { line in print("  " + line) }
        var pass = 0
        WindowStore.shared.snapshot(options) { items in
            pass += 1
            print(pass == 1 ? "Switcher shows \(items.count) windows:" : "After looking on other Spaces, \(items.count) windows:")
            for item in items {
                var notes: [String] = []
                if item.isFullScreen { notes.append("full screen") }
                if let space = item.otherSpace { notes.append("Space \(space)") }
                if item.isMinimized { notes.append("minimized") }
                if !item.isConfirmed { notes.append("from WindowServer only") }
                print("  \(item.appName) — \(item.title)" + (notes.isEmpty ? "" : "  [\(notes.joined(separator: ", "))]"))
            }
        }
        // A second pass may follow once windows on other Spaces are looked up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { exit(0) }
        return true
    }
}
