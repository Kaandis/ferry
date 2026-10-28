import AppKit
import Observation
import SwiftUI

/// Which side of the screen the Dock is on; previews grow out of it.
enum DockEdge { case bottom, left, right }

@MainActor
@Observable
final class DockPreviewModel {
    var items: [WindowItem] = []
    var appName = ""
    var pid: pid_t = 0
    var edge = DockEdge.bottom
    var columns = 1
    var hoveredID: CGWindowID?

    @ObservationIgnored var onOpen: ((WindowItem) -> Void)?
    @ObservationIgnored var onClose: ((WindowItem) -> Void)?
    @ObservationIgnored var onPointerExit: (() -> Void)?
}

/// Sizes shared by the controller (to place the panel) and the view.
enum DockPreviewMetrics {
    static let thumbnail = CGSize(width: 196, height: 122)
    static let cardPadding: CGFloat = 8
    static let cardWidth = thumbnail.width + cardPadding * 2
    static let cardHeight = cardPadding * 2 + thumbnail.height + 6 + 16
    static let spacing: CGFloat = 8
    static let padding: CGFloat = 14
    static let header: CGFloat = 20
    static let margin: CGFloat = 24
    static let maxRows = 3

    static func columns(for count: Int, maxWidth: CGFloat) -> Int {
        let fit = Int((maxWidth - padding * 2 + spacing) / (cardWidth + spacing))
        return max(1, min(count, fit))
    }

    static func surfaceSize(count: Int, maxWidth: CGFloat) -> CGSize {
        let columns = columns(for: count, maxWidth: maxWidth)
        let rows = min(maxRows, Int((Double(count) / Double(columns)).rounded(.up)))
        return CGSize(width: CGFloat(columns) * cardWidth + CGFloat(columns - 1) * spacing + padding * 2,
                      height: padding * 2 + header + 10 + CGFloat(rows) * cardHeight + CGFloat(rows - 1) * spacing)
    }
}

/// Shows an app's windows when you rest the pointer on its Dock icon.
@MainActor
final class DockPreviewController {
    let model = DockPreviewModel()
    private let observer = DockObserver()
    private var panel: FloatingPanel?
    private var lastHover: DockObserver.Hover?
    private var showWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    private var hideGeneration = 0
    private var isShown = false
    private var isSuspended = false
    private var isRunning = false
    private var defaultsToken: NSObjectProtocol?
    private var activationToken: NSObjectProtocol?
    /// Pointer monitors that exist only while a preview is on screen.
    private var pointerMonitors: [Any] = []
    private var dockArea: CGRect = .zero

    func start() {
        model.onOpen = { [weak self] item in
            self?.hide(animated: false)
            WindowActions.focus(item)
        }
        model.onClose = { [weak self] item in self?.close(item) }
        model.onPointerExit = { [weak self] in self?.checkPointer() }
        observer.onChange = { [weak self] hover in self?.hoverChanged(hover) }
        applyEnabled()
        defaultsToken = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyEnabled() }
        }
        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                // Clicking the icon brings the app forward; the preview has done its job.
                if let self, self.isShown, app?.processIdentifier == self.model.pid { self.hide(animated: true) }
            }
        }
    }

    /// Starts or stops listening to the Dock with the setting, so a disabled
    /// feature costs nothing at all.
    private func applyEnabled() {
        let enabled = Prefs.bool(Prefs.dockPreviewsEnabled)
        guard enabled != isRunning else { return }
        isRunning = enabled
        if enabled { observer.start() } else { observer.stop(); hide(animated: false) }
    }

    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        if suspended { hide(animated: false) }
    }

    private func hoverChanged(_ hover: DockObserver.Hover?) {
        lastHover = hover
        guard !isSuspended else { return }
        showWork?.cancel()
        guard let hover else {
            // A short grace: the Dock briefly selects nothing between two icons.
            scheduleHideCheck(after: 0.12)
            return
        }
        hideWork?.cancel()
        if isShown {
            if hover.app.processIdentifier != model.pid { load(hover) }
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.load(hover) }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + UserDefaults.standard.double(forKey: Prefs.dockPreviewDelay),
                                      execute: work)
    }

    private func load(_ hover: DockObserver.Hover) {
        guard !Prefs.excluded.contains(hover.app.bundleIdentifier ?? "") else { hide(animated: true); return }
        var options = WindowStore.Options()
        options.onlyPID = hover.app.processIdentifier
        WindowStore.shared.snapshot(options) { [weak self] items in
            guard let self, self.lastHover?.app.processIdentifier == hover.app.processIdentifier || self.isShown,
                  !self.isSuspended else { return }
            guard !items.isEmpty else { self.hide(animated: true); return }
            self.present(items, for: hover)
        }
    }

    private func present(_ items: [WindowItem], for hover: DockObserver.Hover) {
        let screen = NSScreen.screens.first { $0.quartzFrame.contains(CGPoint(x: hover.iconFrame.midX, y: hover.iconFrame.midY)) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let edge = Self.edge(of: hover.iconFrame, on: screen.quartzFrame)
        let maxWidth = edge == .bottom ? screen.visibleFrame.width * 0.9 : screen.visibleFrame.width * 0.6
        let surface = DockPreviewMetrics.surfaceSize(count: items.count, maxWidth: maxWidth)
        let margin = DockPreviewMetrics.margin
        let size = CGSize(width: surface.width + margin * 2, height: surface.height + margin * 2)

        // Place the surface just off the icon, then keep it on screen.
        let icon = NSScreen.appKitRect(fromQuartz: hover.iconFrame)
        let gap: CGFloat = 6
        var origin: CGPoint
        switch edge {
        case .bottom: origin = CGPoint(x: icon.midX - size.width / 2, y: icon.maxY + gap - margin)
        case .left: origin = CGPoint(x: icon.maxX + gap - margin, y: icon.midY - size.height / 2)
        case .right: origin = CGPoint(x: icon.minX - gap - size.width + margin, y: icon.midY - size.height / 2)
        }
        let bounds = screen.frame.insetBy(dx: -margin + 8, dy: -margin + 8)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)

        log.notice("Dock preview for \(items.count) windows")
        let samePID = isShown && model.pid == hover.app.processIdentifier
        model.items = items
        model.appName = hover.app.localizedName ?? ""
        model.pid = hover.app.processIdentifier
        model.edge = edge
        model.columns = DockPreviewMetrics.columns(for: items.count, maxWidth: maxWidth)
        if !samePID { model.hoveredID = nil }

        let panel = panel ?? makePanel()
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        hideGeneration += 1
        if !isShown {
            isShown = true
            watchPointer()
            if let content = panel.contentView {
                if !panel.isVisible { PanelMotion.setHidden(content, anchor: anchor(in: content), hiddenScale: 0.92, offset: hiddenOffset) }
                panel.orderFrontRegardless()
                PanelMotion.animate(content, presented: true, anchor: anchor(in: content), hiddenScale: 0.92, offset: hiddenOffset)
            }
        }
        ThumbnailCache.shared.refresh(items, olderThan: 2)
    }

    /// While a preview is up, follow the pointer: the Dock reports which icon
    /// is hovered but not when the pointer leaves it, so this is how the
    /// preview knows to go the moment you're neither on the Dock nor on it.
    /// The monitors are removed as soon as the preview hides.
    private func watchPointer() {
        guard pointerMonitors.isEmpty else { return }
        dockArea = observer.dockFrame.map { NSScreen.appKitRect(fromQuartz: $0) } ?? .zero
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPointer() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            pointerMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { event in
            handler(event)
            return event
        }) {
            pointerMonitors.append(local)
        }
    }

    private func stopWatchingPointer() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors.removeAll()
    }

    private func checkPointer() {
        guard isShown else { return }
        let point = NSEvent.mouseLocation
        let onPreview = panel?.frame.contains(point) ?? false
        let onDock = dockArea.insetBy(dx: -2, dy: -2).contains(point)
        if !onPreview && !onDock { hide(animated: true) }
    }

    private func scheduleHideCheck(after delay: TimeInterval) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isShown else { return }
            let pointerInside = self.panel?.frame.contains(NSEvent.mouseLocation) ?? false
            if self.lastHover == nil && !pointerInside { self.hide(animated: true) }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func hide(animated: Bool) {
        showWork?.cancel()
        hideWork?.cancel()
        guard isShown else { return }
        isShown = false
        stopWatchingPointer()
        hideGeneration += 1
        let generation = hideGeneration
        guard animated, let content = panel?.contentView else {
            panel?.orderOut(nil)
            return
        }
        PanelMotion.animate(content, presented: false, anchor: anchor(in: content), hiddenScale: 0.92, offset: hiddenOffset) { [weak self] in
            guard let self, generation == self.hideGeneration else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func close(_ item: WindowItem) {
        WindowActions.close(item)
        withAnimation(reduceMotion ? nil : .harborPresent) {
            model.items.removeAll { $0.id == item.id }
        }
        if model.items.isEmpty { hide(animated: true) }
    }

    /// The edge of the surface nearest the Dock, in the content view's bounds (y up).
    private func anchor(in view: NSView) -> CGPoint {
        let margin = DockPreviewMetrics.margin
        let bounds = view.bounds
        switch model.edge {
        case .bottom: return CGPoint(x: bounds.midX, y: margin)
        case .left: return CGPoint(x: margin, y: bounds.midY)
        case .right: return CGPoint(x: bounds.maxX - margin, y: bounds.midY)
        }
    }

    /// Hidden, the preview sits a little toward the Dock.
    private var hiddenOffset: CGSize {
        switch model.edge {
        case .bottom: CGSize(width: 0, height: -10)
        case .left: CGSize(width: -10, height: 0)
        case .right: CGSize(width: 10, height: 0)
        }
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel()
        let content = FirstMouseHostingView(rootView: DockPreviewRoot(model: model))
        content.wantsLayer = true
        panel.contentView = content
        self.panel = panel
        return panel
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func edge(of icon: CGRect, on screen: CGRect) -> DockEdge {
        let bottom = screen.maxY - icon.maxY
        let left = icon.minX - screen.minX
        let right = screen.maxX - icon.maxX
        if bottom <= min(left, right) { return .bottom }
        return left < right ? .left : .right
    }
}

private struct DockPreviewRoot: View {
    let model: DockPreviewModel
    @AppStorage(Prefs.panelStyle) private var style = "cream"
    @AppStorage(Prefs.accentColor) private var accent = "pebble"

    var body: some View {
        DockPreviewView(model: model, thumbnails: ThumbnailCache.shared,
                        showsPictures: Permissions.shared.screenRecording)
            .environment(\.palette, .named(style))
            .environment(\.accent, .named(accent))
            .padding(DockPreviewMetrics.margin)
    }
}
