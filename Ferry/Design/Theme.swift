import AppKit
import SwiftUI

/// Harbor design tokens. Kept free of Ferry specifics so they can move into
/// HarborKit unchanged.
enum Theme {
    static let background = dynamic(light: 0xfbf3ea, dark: 0x1d1916)
    static let raised = dynamic(light: 0xf4e8da, dark: 0x29231f)
    static let card = dynamic(light: 0xfffbf6, dark: 0x332c27)
    static let ink = dynamic(light: 0x231f1c, dark: 0xf6ece2)
    static let ink2 = dynamic(light: 0x6e625a, dark: 0xc0b1a4)
    static let ink3 = dynamic(light: 0x857568, dark: 0x9e8e80)
    static let coral = Color(nsColor: NSColor(hex: 0xe8664f))
    static let coralText = dynamic(light: 0xc4503b, dark: 0xf2907c)
    static let hairline = dynamic(light: 0x231f1c, dark: 0xffffff, alpha: 0.08)

    /// The tint laid over a translucent surface, so glass reads cream rather than grey.
    static let surfaceTint = dynamic(light: 0xfbf3ea, dark: 0x1d1916, alpha: 0.78)

    private static func dynamic(light: Int, dark: Int, alpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }
}

/// Springs. Critically damped by default; nothing in Ferry is flung, so
/// nothing bounces. SwiftUI springs retarget from the current value and
/// velocity, which keeps every transition interruptible.
extension Animation {
    /// Panels appearing and leaving.
    static let harborPresent = Animation.spring(response: 0.28, dampingFraction: 1)
    /// The selection sliding between tiles.
    static let harborSelect = Animation.spring(response: 0.2, dampingFraction: 1)
    /// Press feedback: short and immediate.
    static let harborPress = Animation.spring(response: 0.12, dampingFraction: 1)
}

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }
}

/// The colours a floating panel draws with. Cream is Harbor's own look;
/// Liquid Glass hands the surface to the system and switches text to
/// vibrant system colours so it reads over any wallpaper.
struct Palette {
    var isGlass = false
    var ink = Theme.ink
    var ink2 = Theme.ink2
    var ink3 = Theme.ink3
    var card = Theme.card
    var raised = Theme.raised
    var hairline = Theme.hairline

    static let cream = Palette()
    static let glass = Palette(isGlass: true,
                               ink: .primary,
                               ink2: .secondary,
                               ink3: Color(nsColor: .tertiaryLabelColor),
                               card: Color.primary.opacity(0.07),
                               raised: Color.primary.opacity(0.06),
                               hairline: Color.primary.opacity(0.1))

    /// Liquid Glass needs macOS 26; earlier systems keep the cream panel.
    static func named(_ style: String) -> Palette {
        if #available(macOS 26, *), style == "glass" { return .glass }
        return .cream
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.cream }
private struct StaticRenderKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True while `ImageRenderer` draws a view: AppKit-backed materials don't
    /// render there, so surfaces fall back to their solid colour.
    var isStaticRender: Bool {
        get { self[StaticRenderKey.self] }
        set { self[StaticRenderKey.self] = newValue }
    }

    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// A floating Harbor surface: system glass under a cream tint, or Liquid
/// Glass if chosen. Solid when the user asks for less transparency, outlined
/// when they ask for more contrast.
struct HarborSurface: View {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isStaticRender) private var isStaticRender
    @Environment(\.palette) private var palette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if reduceTransparency || isStaticRender {
                shape.fill(palette.isGlass ? Color(nsColor: .windowBackgroundColor) : Theme.background)
            } else if palette.isGlass, #available(macOS 26, *) {
                LiquidGlass(cornerRadius: cornerRadius)
            } else {
                VisualEffectBlur()
                    .clipShape(shape)
                shape.fill(Theme.surfaceTint)
            }
        }
        .overlay(
            shape.strokeBorder(contrast == .increased ? palette.ink2 : palette.hairline,
                               lineWidth: contrast == .increased ? 1.5 : 1)
        )
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// AppKit's Liquid Glass view, as a panel background.
@available(macOS 26, *)
private struct LiquidGlass: NSViewRepresentable {
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.cornerRadius = cornerRadius
    }
}
