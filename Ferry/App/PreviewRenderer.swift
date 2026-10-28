#if DEBUG
import AppKit
import SwiftUI
import HarborKit

/// `Ferry --render-previews <dir>` writes a PNG of every UI state and exits.
/// Uses made-up apps and drawn window pictures, so the UI can be checked
/// without Screen Recording permission and without showing anyone's windows.
/// Add `--transparent` to drop the backdrop (for the website and README).
@MainActor
enum PreviewRenderer {
    static func runIfRequested() {
        let args = CommandLine.arguments
        if args.contains("--permission-status") {
            print("accessibility=\(AXIsProcessTrusted()) screenRecording=\(CGPreflightScreenCaptureAccess())")
            exit(0)
        }
        guard let i = args.firstIndex(of: "--render-previews"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        let transparent = args.contains("--transparent")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Prefs.registerDefaults()

        let items = sampleItems()
        let screen = CGSize(width: 1440, height: 900)

        func switcher(_ name: String, selected: Int = 1, query: String? = nil, pictures: Bool = true,
                      dark: Bool = false, count: Int? = nil, selection: Bool = true, to target: URL? = nil) {
            let model = SwitcherModel()
            model.items = Array(items.prefix(count ?? items.count))
            model.screenSize = screen
            model.isPresented = true
            if let query {
                model.isSearching = true
                model.query = query
                model.selectFirstMatch()
            } else {
                model.selectedID = model.items[min(selected, model.items.count - 1)].id
            }
            let view = SwitcherView(model: model, thumbnails: ThumbnailCache.shared, showsPictures: pictures,
                                    showsSelection: selection)
                .frame(width: 1360, height: model.layout.rows > 1 ? 760 : 480)
            write(view, name: name, dark: dark, transparent: transparent, to: target ?? dir)
        }

        // `--gif` adds the frames scripts/make-gif.py turns into the README animation.
        if args.contains("--gif") {
            let frames = dir.appendingPathComponent("gif", isDirectory: true)
            try? FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
            switcher("base", selection: false, to: frames)
            for index in 0..<items.count { switcher("sel-\(index)", selected: index, to: frames) }
        }

        switcher("1-switcher")
        switcher("2-switcher-search", query: "Harbor")
        switcher("3-switcher-icons", pictures: false)
        switcher("4-switcher-dark", selected: 2, dark: true)
        switcher("5-switcher-few", selected: 1, count: 3)

        let dock = DockPreviewModel()
        dock.items = items.filter { $0.pid == 1002 }
        dock.appName = "Compass"
        dock.pid = 1002
        dock.columns = dock.items.count
        dock.hoveredID = dock.items.first?.id
        write(DockPreviewView(model: dock, thumbnails: ThumbnailCache.shared, showsPictures: true).padding(40),
              name: "6-dock-preview", dark: false, transparent: transparent, to: dir)
        write(DockPreviewView(model: dock, thumbnails: ThumbnailCache.shared, showsPictures: true).padding(40),
              name: "7-dock-preview-dark", dark: true, transparent: transparent, to: dir)

        Permissions.shared.override(accessibility: false, screenRecording: false)
        write(OnboardingView {}, name: "8-onboarding", dark: false, transparent: true, to: dir)
        Permissions.shared.override(accessibility: true, screenRecording: false)
        write(OnboardingView {}, name: "9-onboarding-half", dark: false, transparent: true, to: dir)
        exit(0)
    }

    private static func write(_ view: some View, name: String, dark: Bool, transparent: Bool, to dir: URL) {
        let backdrop = dark ? Color(red: 0.16, green: 0.14, blue: 0.13) : Color(red: 0.93, green: 0.89, blue: 0.84)
        let content = view
            .background(transparent ? Color.clear : backdrop)
            .environment(\.isStaticRender, true)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.locale, AppLanguage.resolvedLocale)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }

    // MARK: Sample data

    private struct SampleApp {
        let pid: pid_t
        let name: String
        let symbol: String
        let color: NSColor
    }

    private static var isTurkish: Bool { AppLanguage.resolvedLocale.identifier.hasPrefix("tr") }

    private static func sampleItems() -> [WindowItem] {
        let apps = [
            SampleApp(pid: 1001, name: "Driftwood", symbol: "text.alignleft", color: NSColor(hex: 0xe8a33d)),
            SampleApp(pid: 1002, name: "Compass", symbol: "safari", color: NSColor(hex: 0x3d7be8)),
            SampleApp(pid: 1003, name: "Lantern", symbol: "photo.on.rectangle", color: NSColor(hex: 0xd9546e)),
            SampleApp(pid: 1004, name: "Keel", symbol: "chevron.left.forwardslash.chevron.right", color: NSColor(hex: 0x2f2a26)),
            SampleApp(pid: 1005, name: "Gull Mail", symbol: "envelope", color: NSColor(hex: 0x3fa58a)),
            SampleApp(pid: 1006, name: "Sketchboard", symbol: "pencil.and.outline", color: NSColor(hex: 0x8a5cd6)),
        ]
        for app in apps { AppIcons.overrides[app.pid] = icon(app) }

        let tr = isTurkish
        let windows: [(pid_t, String, Kind, CGSize, (inout WindowItem) -> Void)] = [
            (1001, tr ? "Ferry lansman notları" : "Ferry launch notes", .notes, CGSize(width: 1100, height: 760), { _ in }),
            (1002, tr ? "Harbor — Ücretsiz Mac uygulamaları" : "Harbor — Free Mac apps", .browser, CGSize(width: 1440, height: 900), { _ in }),
            (1004, "ferry — WindowStore.swift", .code, CGSize(width: 1200, height: 800), { _ in }),
            (1003, tr ? "Sahil, Ekim" : "Coastline, October", .photos, CGSize(width: 1280, height: 820), { $0.otherSpace = 2; $0.isOnScreen = false }),
            (1005, tr ? "Gelen Kutusu — 3 yeni" : "Inbox — 3 new", .mail, CGSize(width: 1300, height: 820), { _ in }),
            (1002, tr ? "Harbor Dock taslağı" : "Harbor Dock draft", .browser, CGSize(width: 1200, height: 860), { $0.isMinimized = true; $0.isOnScreen = false }),
            (1006, tr ? "Ferry ikonu" : "Ferry icon", .design, CGSize(width: 1180, height: 780), { _ in }),
            (1001, tr ? "Alışveriş listesi" : "Groceries", .notes, CGSize(width: 800, height: 900), { $0.otherSpace = 3; $0.isOnScreen = false }),
            (1002, tr ? "Hava durumu — İstanbul" : "Weather — Istanbul", .browser, CGSize(width: 1100, height: 800), { _ in }),
        ]
        return windows.enumerated().map { index, entry in
            let (pid, title, kind, size, adjust) = entry
            let app = apps.first { $0.pid == pid }!
            let id = CGWindowID(5000 + index)
            var item = WindowItem(id: id, pid: pid, bundleID: nil, appName: app.name, title: title,
                                  frame: CGRect(origin: .zero, size: size))
            adjust(&item)
            if let image = window(kind, size: size, accent: app.color) { ThumbnailCache.shared.inject(image, for: id) }
            return item
        }
    }

    private static func icon(_ app: SampleApp) -> NSImage {
        NSImage(size: NSSize(width: 128, height: 128), flipped: false) { rect in
            let body = NSBezierPath(roundedRect: rect.insetBy(dx: 12, dy: 12), xRadius: 26, yRadius: 26)
            app.color.setFill()
            body.fill()
            let config = NSImage.SymbolConfiguration(pointSize: 50, weight: .semibold)
                .applying(.init(paletteColors: [.white]))
            if let symbol = NSImage(systemSymbolName: app.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let size = symbol.size
                symbol.draw(in: NSRect(x: (128 - size.width) / 2, y: (128 - size.height) / 2,
                                       width: size.width, height: size.height))
            }
            return true
        }
    }

    private enum Kind { case notes, browser, code, photos, mail, design }

    /// Draws a plausible window at thumbnail resolution.
    private static func window(_ kind: Kind, size: CGSize, accent: NSColor) -> CGImage? {
        let scale = ThumbnailCache.maxPixels / max(size.width, size.height)
        let w = size.width * scale, h = size.height * scale
        let image = NSImage(size: NSSize(width: w, height: h), flipped: true) { _ in
            let dark = kind == .code
            (dark ? NSColor(hex: 0x1f1c1a) : NSColor(hex: 0xfffdf9)).setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: h), xRadius: 10, yRadius: 10).fill()
            (dark ? NSColor(hex: 0x2a2623) : NSColor(hex: 0xf3ece3)).setFill()
            NSRect(x: 0, y: 0, width: w, height: 26).fill()
            for (i, hex) in [0xe8664f, 0xe8b14f, 0x6fbf73].enumerated() {
                NSColor(hex: hex).setFill()
                NSBezierPath(ovalIn: NSRect(x: 12 + CGFloat(i) * 16, y: 8, width: 10, height: 10)).fill()
            }
            func bar(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ color: NSColor, _ height: CGFloat = 7) {
                color.setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: height / 2, yRadius: height / 2).fill()
            }
            let ink = NSColor(hex: 0x231f1c, alpha: 0.16)
            switch kind {
            case .notes:
                NSColor(hex: 0xf7efe4).setFill()
                NSRect(x: 0, y: 26, width: w * 0.28, height: h - 26).fill()
                for row in 0..<7 { bar(14, 46 + CGFloat(row) * 26, w * 0.2, row == 1 ? accent.withAlphaComponent(0.5) : ink) }
                bar(w * 0.33, 50, w * 0.4, NSColor(hex: 0x231f1c, alpha: 0.7), 12)
                for row in 0..<12 { bar(w * 0.33, 82 + CGFloat(row) * 20, w * (row % 4 == 3 ? 0.35 : 0.58), ink) }
            case .browser:
                bar(w * 0.2, 7, w * 0.6, NSColor(hex: 0xffffff), 12)
                accent.withAlphaComponent(0.85).setFill()
                NSRect(x: 0, y: 26, width: w, height: h * 0.42).fill()
                bar(w * 0.08, h * 0.17, w * 0.45, .white, 16)
                bar(w * 0.08, h * 0.17 + 28, w * 0.3, NSColor.white.withAlphaComponent(0.7))
                for column in 0..<3 {
                    let x = w * 0.06 + CGFloat(column) * w * 0.31
                    NSColor(hex: 0xf3ece3).setFill()
                    NSBezierPath(roundedRect: NSRect(x: x, y: h * 0.56, width: w * 0.27, height: h * 0.3), xRadius: 8, yRadius: 8).fill()
                }
            case .code:
                let palette = [0xe8664f, 0xe8b14f, 0x8fc1e3, 0xb59ce6, 0x8bc48a, 0xf6ece2]
                for row in 0..<22 {
                    let indent = CGFloat([0, 1, 2, 2, 1, 2, 3, 3, 2, 1, 0][row % 11]) * 18
                    bar(16 + indent, 40 + CGFloat(row) * 15, w * CGFloat([0.3, 0.45, 0.22, 0.5, 0.36][row % 5]),
                        NSColor(hex: palette[row % palette.count], alpha: 0.75), 6)
                }
            case .photos:
                let palettes = [0xe8a07a, 0x7ab0d6, 0xd9c27a, 0xa7c98f, 0xd68ba0, 0x9f8fd1, 0xe0b48c, 0x86c2b8]
                let cell = (w - 40) / 4
                for index in 0..<12 {
                    let x = 12 + CGFloat(index % 4) * (cell + 5), y = 38 + CGFloat(index / 4) * (cell * 0.72 + 5)
                    NSColor(hex: palettes[index % palettes.count]).setFill()
                    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: cell, height: cell * 0.72), xRadius: 5, yRadius: 5).fill()
                }
            case .mail:
                NSColor(hex: 0xf7efe4).setFill()
                NSRect(x: 0, y: 26, width: w * 0.36, height: h - 26).fill()
                for row in 0..<7 {
                    let y = 40 + CGFloat(row) * 40
                    if row == 0 { accent.withAlphaComponent(0.2).setFill(); NSRect(x: 0, y: y - 6, width: w * 0.36, height: 38).fill() }
                    bar(14, y, w * 0.18, NSColor(hex: 0x231f1c, alpha: 0.55))
                    bar(14, y + 14, w * 0.28, ink)
                }
                bar(w * 0.41, 50, w * 0.35, NSColor(hex: 0x231f1c, alpha: 0.7), 12)
                for row in 0..<9 { bar(w * 0.41, 84 + CGFloat(row) * 20, w * (row % 3 == 2 ? 0.3 : 0.5), ink) }
            case .design:
                NSColor(hex: 0xefe6db).setFill()
                NSRect(x: w * 0.18, y: 26, width: w * 0.64, height: h - 26).fill()
                NSColor(hex: 0xf6e7d6).setFill()
                NSBezierPath(roundedRect: NSRect(x: w * 0.38, y: h * 0.3, width: w * 0.24, height: w * 0.24), xRadius: 22, yRadius: 22).fill()
                NSColor(hex: 0xe8664f).setStroke()
                let ring = NSBezierPath(roundedRect: NSRect(x: w * 0.43, y: h * 0.3 + w * 0.04, width: w * 0.14, height: w * 0.15), xRadius: 10, yRadius: 10)
                ring.lineWidth = 4
                ring.stroke()
                for row in 0..<6 { bar(10, 40 + CGFloat(row) * 22, w * 0.13, ink) }
                for row in 0..<6 { bar(w * 0.85, 40 + CGFloat(row) * 22, w * 0.11, ink) }
            }
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: [.ctm: NSAffineTransform()])
    }
}
#endif
