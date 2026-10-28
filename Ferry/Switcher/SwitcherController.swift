import AppKit
import SwiftUI

/// Runs the switcher: hold the modifier, tap Tab to step, let go to switch.
///
/// A quick tap-and-release swaps to the previous window without the panel
/// ever appearing; the panel only shows if the modifier is still held a
/// moment later, the way the system switcher feels.
@MainActor
final class SwitcherController {
    let model = SwitcherModel()
    /// Tells the Dock previews to step aside while the switcher is up.
    var onActiveChange: ((Bool) -> Void)?

    private let tap = HotkeyTap()
    private var panel: FloatingPanel?

    private enum Phase { case idle, pending, shown }
    private var phase = Phase.idle
    private var showWork: DispatchWorkItem?
    private var hideGeneration = 0
    private var itemsLoaded = false
    private var pendingSteps = 0
    private var commitWhenLoaded = false
    private var swallowedKeyUps: Set<Int64> = []
    private var holdMask = CGEventFlags.maskAlternate
    private var appliedMask: CGEventFlags?
    private var defaultsToken: NSObjectProtocol?
    private var openedAt = Date()

    private static let showDelay: TimeInterval = 0.09
    private static let modifierMasks: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl]

    var isActive: Bool { phase != .idle }

    /// Starts listening for the shortcut. Safe to call again once Accessibility is granted.
    func start() {
        guard defaultsToken == nil else { tap.start(); return }
        model.onCommit = { [weak self] item in
            self?.model.selectedID = item.id
            self?.commit()
        }
        model.onCancel = { [weak self] in self?.dismiss() }
        tap.handler = { [weak self] kind, key in self?.handle(kind, key) ?? false }
        tap.start()
        readPrefs()
        #if DEBUG
        listenForDebugCommands()
        #endif
        defaultsToken = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.readPrefs() }
        }
    }

    func stop() {
        tap.stop()
        PrivateAPI.setSystemCommandTab(enabled: true)
    }

    private func readPrefs() {
        let mask: CGEventFlags = switch Prefs.string(Prefs.switcherModifier) {
        case "command": .maskCommand
        case "control": .maskControl
        default: .maskAlternate
        }
        holdMask = mask
        guard mask != appliedMask else { return }
        appliedMask = mask
        // Taking over ⌘Tab means switching the system's own one off.
        PrivateAPI.setSystemCommandTab(enabled: mask != .maskCommand)
    }

    // MARK: Keys

    private func handle(_ kind: HotkeyTap.Kind, _ key: HotkeyTap.Key) -> Bool {
        switch kind {
        case .modifiers:
            if phase != .idle && !model.isSearching && !key.flags.contains(holdMask) { commit() }
            return false
        case .up:
            return swallowedKeyUps.remove(key.code) != nil
        case .down:
            if phase == .idle {
                guard key.code == KeyCode.tab,
                      key.flags.intersection(Self.modifierMasks) == holdMask,
                      !isOwnWebsiteInFront() else { return false }
                swallowedKeyUps.insert(key.code)
                open(step: key.flags.contains(.maskShift) ? -1 : 1)
                return true
            }
            swallowedKeyUps.insert(key.code)
            handleWhileOpen(key)
            return true
        }
    }

    private func handleWhileOpen(_ key: HotkeyTap.Key) {
        let backwards = key.flags.contains(.maskShift)
        let columns = model.layout.columns
        switch key.code {
        case KeyCode.tab: step(backwards ? -1 : 1)
        case KeyCode.right: step(1)
        case KeyCode.left: step(-1)
        case KeyCode.down: step(columns)
        case KeyCode.up: step(-columns)
        case KeyCode.escape: dismiss()
        case KeyCode.returnKey, KeyCode.enter: commit()
        case KeyCode.delete where model.isSearching:
            if !model.query.isEmpty { model.query.removeLast() }
            model.selectFirstMatch()
        case KeyCode.space where !model.isSearching:
            animate(.harborPresent) { model.isSearching = true }
        default:
            let text = key.characters
            if model.isSearching {
                let printable = text.filter { !$0.isNewline && $0.unicodeScalars.allSatisfy { $0.value >= 32 } }
                guard !printable.isEmpty else { return }
                model.query += printable
                model.selectFirstMatch()
            } else {
                switch text.lowercased() {
                case "w": act(WindowActions.close) { items, item in items.removeAll { $0.id == item.id } }
                case "m": act(WindowActions.minimize) { items, item in
                    if let i = items.firstIndex(where: { $0.id == item.id }) { items[i].isMinimized.toggle() }
                }
                case "h": act(WindowActions.hide) { items, item in
                    for i in items.indices where items[i].pid == item.pid { items[i].isAppHidden.toggle() }
                }
                case "q": act(WindowActions.quit) { items, item in items.removeAll { $0.pid == item.pid } }
                default: break
                }
            }
        }
    }

    /// Ferry's website has a demo that answers to ⌥Tab itself. When that page
    /// is in front, Ferry lets the shortcut through so the demo can be tried
    /// with Ferry installed. Checked only when the shortcut is pressed.
    private func isOwnWebsiteInFront() -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        var window: CFTypeRef?
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID(),
              AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success
        else { return false }
        return (title as? String)?.hasPrefix("Ferry — ") ?? false
    }

    // MARK: Flow

    private func open(step: Int) {
        openedAt = Date()
        let screen = targetScreen()
        phase = .pending
        itemsLoaded = false
        commitWhenLoaded = false
        pendingSteps = step
        model.reset()
        model.screenSize = screen.visibleFrame.size
        onActiveChange?(true)

        var options = WindowStore.Options()
        options.allSpaces = Prefs.string(Prefs.switcherSpaces) != "current"
        options.includeMinimized = Prefs.bool(Prefs.showMinimized)
        options.includeHidden = Prefs.bool(Prefs.showHidden)
        options.excludedBundleIDs = Prefs.excluded
        if Prefs.string(Prefs.switcherDisplays) == "current" { options.display = screen.quartzFrame }
        WindowStore.shared.snapshot(options) { [weak self] items in self?.receive(items) }

        position(on: screen)
        if panel?.isVisible == true {
            // Reopened while the last one was still leaving: turn it around from where it is.
            show()
        } else {
            let work = DispatchWorkItem { [weak self] in self?.show() }
            showWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.showDelay, execute: work)
        }
    }

    private func receive(_ items: [WindowItem]) {
        guard phase != .idle else { return }
        log.notice("Switcher got \(items.count) windows \(Int(Date().timeIntervalSince(self.openedAt) * 1000)) ms after the shortcut")
        #if DEBUG
        for item in items {
            log.notice("  \(item.id) \(item.appName, privacy: .public): \(item.title, privacy: .public) onScreen=\(item.isOnScreen) min=\(item.isMinimized) hidden=\(item.isAppHidden) full=\(item.isFullScreen) space=\(item.otherSpace ?? 0) ax=\(item.isConfirmed) \(Int(item.frame.width))x\(Int(item.frame.height))")
        }
        #endif
        let kept = model.selectedID
        model.items = items
        if itemsLoaded {
            if let kept, items.contains(where: { $0.id == kept }) { model.selectedID = kept }
            ThumbnailCache.shared.refresh(items, olderThan: 1)
            return
        }
        itemsLoaded = true
        if !items.isEmpty {
            let count = items.count
            model.selectedID = items[((pendingSteps % count) + count) % count].id
        }
        if commitWhenLoaded {
            commit()
        } else {
            ThumbnailCache.shared.refresh(items, olderThan: 1)
        }
    }

    private func step(_ offset: Int) {
        guard itemsLoaded else { pendingSteps += offset; return }
        animate(.harborSelect) { model.move(by: offset) }
    }

    private func show() {
        guard phase == .pending || (phase == .shown && panel?.isVisible == true) else { return }
        phase = .shown
        hideGeneration += 1
        guard let panel, let content = panel.contentView else { return }
        model.isPresented = true
        panel.orderFrontRegardless()
        PanelMotion.animate(content, presented: true, anchor: center(of: content))
    }

    private func center(of view: NSView) -> CGPoint { CGPoint(x: view.bounds.midX, y: view.bounds.midY) }

    private func commit() {
        guard phase != .idle else { return }
        guard itemsLoaded else { commitWhenLoaded = true; return }
        let item = model.selectedItem
        dismiss()
        if let item { WindowActions.focus(item) }
    }

    private func dismiss() {
        guard phase != .idle else { return }
        showWork?.cancel()
        showWork = nil
        let wasShown = phase == .shown
        phase = .idle
        onActiveChange?(false)
        guard wasShown else { return }
        hideGeneration += 1
        let generation = hideGeneration
        guard let content = panel?.contentView else { return }
        PanelMotion.animate(content, presented: false, anchor: center(of: content)) { [weak self] in
            guard let self, generation == self.hideGeneration, self.phase == .idle else { return }
            self.panel?.orderOut(nil)
            self.model.isPresented = false
            self.model.reset()
            ThumbnailCache.shared.trim()
        }
    }

    /// Runs an action on the selected window and updates the list right away,
    /// then once more from the system a moment later.
    private func act(_ action: (WindowItem) -> Void, optimistic: (inout [WindowItem], WindowItem) -> Void) {
        guard let item = model.selectedItem else { return }
        let index = model.visibleItems.firstIndex { $0.id == item.id } ?? 0
        action(item)
        animate(.harborPresent) {
            optimistic(&model.items, item)
            let list = model.visibleItems
            if !list.contains(where: { $0.id == model.selectedID }), !list.isEmpty {
                model.selectedID = list[min(index, list.count - 1)].id
            }
        }
    }

    // MARK: Panel

    private func position(on screen: NSScreen) {
        let panel = panel ?? makePanel()
        let moved = panel.frame != screen.frame
        panel.setFrame(screen.frame, display: false)
        if moved && !panel.isVisible, let content = panel.contentView {
            PanelMotion.setHidden(content, anchor: center(of: content))
        }
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel()
        let root = SwitcherRoot(model: model)
        let content = FirstMouseHostingView(rootView: root)
        panel.contentView = content
        content.wantsLayer = true
        self.panel = panel
        return panel
    }

    private func targetScreen() -> NSScreen {
        if Prefs.string(Prefs.switcherPlacement) == "active", let main = NSScreen.main { return main }
        return NSScreen.withMouse ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func animate(_ animation: Animation, _ body: () -> Void) {
        withAnimation(reduceMotion ? nil : animation, body)
    }
}

#if DEBUG
extension SwitcherController {
    /// Lets scripts drive the switcher without synthesizing keys:
    /// `app.ferry.debug` distributed notifications with object
    /// "open", "next", "back", "commit", "cancel", "search", or "type:<text>".
    fileprivate func listenForDebugCommands() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("app.ferry.debug"), object: nil, queue: .main
        ) { [weak self] note in
            let command = note.object as? String ?? ""
            MainActor.assumeIsolated { self?.debug(command) }
        }
    }

    private func debug(_ command: String) {
        switch command {
        case "open": if !isActive { open(step: 1) }
        case "next": step(1)
        case "back": step(-1)
        case "commit": commit()
        case "cancel": dismiss()
        case "search": animate(.harborPresent) { model.isSearching = true }
        case _ where command.hasPrefix("key:"):
            // A key pressed while ⌥ is held, by virtual key code.
            if let code = Int64(command.dropFirst(4)) { handleWhileOpen(HotkeyTap.Key(code: code, flags: .maskAlternate)) }
        default:
            if command.hasPrefix("type:") {
                model.query += command.dropFirst(5)
                model.selectFirstMatch()
            }
        }
    }
}
#endif

/// Reads permission and picture state so the view updates when either changes.
private struct SwitcherRoot: View {
    let model: SwitcherModel
    @AppStorage(Prefs.panelStyle) private var style = "cream"

    var body: some View {
        SwitcherView(model: model, thumbnails: ThumbnailCache.shared,
                     showsPictures: Permissions.shared.screenRecording)
            .environment(\.palette, .named(style))
    }
}
