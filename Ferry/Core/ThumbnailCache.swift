import AppKit
import Observation
import ScreenCaptureKit

/// Window pictures, captured with ScreenCaptureKit only when something is
/// about to show them, then kept until the window goes away.
///
/// Captures happen at three moments: when the switcher opens (windows on
/// screen now), when a Dock preview opens (that app's windows), and when you
/// leave an app (the window you were looking at), which keeps pictures of
/// windows on other Spaces fresh without ever polling.
@MainActor
@Observable
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private(set) var images: [CGWindowID: CGImage] = [:]
    @ObservationIgnored private var capturedAt: [CGWindowID: Date] = [:]
    @ObservationIgnored private var scWindows: [CGWindowID: SCWindow] = [:]
    @ObservationIgnored private var inFlight: Set<CGWindowID> = []
    @ObservationIgnored private var activationToken: NSObjectProtocol?
    @ObservationIgnored private var frontPID: pid_t?

    /// Longest side of a stored picture, in pixels. Tiles are at most ~260 pt
    /// wide, so this stays sharp on Retina without holding full-size frames.
    nonisolated static let maxPixels: CGFloat = 560
    private static let maxEntries = 120

    func start() {
        guard activationToken == nil else { return }
        frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.appDidActivate(app) }
        }
        // Picture what's on screen now, so the first switch already has pictures.
        WindowStore.shared.snapshot(.init(allSpaces: false, includeMinimized: false, includeHidden: false,
                                          lookUpOtherSpaces: false)) { [weak self] items in
            self?.refresh(items)
        }
    }

    /// Pictures the window of the app you just left, if its picture is old.
    private func appDidActivate(_ app: NSRunningApplication?) {
        defer { frontPID = app?.processIdentifier }
        guard let previous = frontPID, previous != app?.processIdentifier, previous != getpid(),
              Permissions.shared.screenRecording else { return }
        WindowStore.shared.snapshot(.init(allSpaces: false, includeMinimized: false, includeHidden: false,
                                          onlyPID: previous, lookUpOtherSpaces: false)) { [weak self] items in
            guard let first = items.first(where: \.isOnScreen) else { return }
            self?.refresh([first], olderThan: 20)
        }
    }

    /// Captures every listed window that is on screen and whose picture is
    /// older than `olderThan` seconds.
    func refresh(_ items: [WindowItem], olderThan maxAge: TimeInterval = 0) {
        guard Permissions.shared.screenRecording else { return }
        let now = Date()
        let targets = items.filter { item in
            item.isOnScreen && !item.isMinimized && !inFlight.contains(item.id)
                && now.timeIntervalSince(capturedAt[item.id] ?? .distantPast) > maxAge
        }
        guard !targets.isEmpty else { return }
        inFlight.formUnion(targets.map(\.id))

        Task {
            let windows = await shareableWindows(for: Set(targets.map(\.id)))
            await withTaskGroup(of: (CGWindowID, CGImage?).self) { group in
                for item in targets {
                    guard let window = windows[item.id] else { continue }
                    group.addTask { (item.id, try? await Self.capture(window)) }
                }
                for await (id, image) in group {
                    if let image {
                        images[id] = image
                        capturedAt[id] = Date()
                    }
                }
            }
            inFlight.subtract(targets.map(\.id))
            trim()
        }
    }

    /// SCWindow handles are reused between captures; the shareable-content
    /// query (which lists every window on the system) runs only when a window
    /// is new to us.
    private func shareableWindows(for ids: Set<CGWindowID>) async -> [CGWindowID: SCWindow] {
        if !ids.isSubset(of: scWindows.keys) {
            if let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) {
                scWindows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
            }
        }
        return scWindows.filter { ids.contains($0.key) }
    }

    nonisolated private static func capture(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        var size = CGSize(width: window.frame.width * scale, height: window.frame.height * scale)
        let fit = min(1, maxPixels / max(size.width, size.height, 1))
        size = CGSize(width: max(1, (size.width * fit).rounded()), height: max(1, (size.height * fit).rounded()))

        let config = SCStreamConfiguration()
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.scalesToFit = true
        config.preservesAspectRatio = true
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.ignoreGlobalClipSingleWindow = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Forgets pictures of windows that no longer exist, and the oldest ones past the cap.
    func trim() {
        if let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] {
            let alive = Set(list.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
            for id in images.keys where !alive.contains(id) { forget(id) }
            for id in scWindows.keys where !alive.contains(id) { scWindows[id] = nil }
        }
        if images.count > Self.maxEntries {
            let oldest = capturedAt.sorted { $0.value < $1.value }.prefix(images.count - Self.maxEntries)
            oldest.forEach { forget($0.key) }
        }
    }

    private func forget(_ id: CGWindowID) {
        images[id] = nil
        capturedAt[id] = nil
    }

    #if DEBUG
    func inject(_ image: CGImage, for id: CGWindowID) { images[id] = image }
    #endif
}
