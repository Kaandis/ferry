import AppKit
import SwiftUI

/// A window's picture, or its app icon on a soft card when there's no picture
/// (no Screen Recording permission, or a minimized window seen for the first time).
struct WindowThumbnail: View {
    let item: WindowItem
    let image: CGImage?
    let size: CGSize

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 2)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 1.5)
                    .opacity(item.isMinimized ? 0.55 : 1)
                    .overlay(alignment: .topTrailing) { StatusBadges(item: item).padding(6) }
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.raised)
                    .overlay(
                        Image(nsImage: AppIcons.icon(for: item.pid))
                            .resizable()
                            .frame(width: min(64, size.height * 0.5), height: min(64, size.height * 0.5))
                    )
                    .overlay(alignment: .topTrailing) { StatusBadges(item: item).padding(6) }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Small chips for windows that aren't simply on screen: minimized, hidden,
/// full screen or on another Space.
struct StatusBadges: View {
    let item: WindowItem

    var body: some View {
        HStack(spacing: 4) {
            if item.isMinimized { chip(symbol: "minus", label: String(localized: "Minimized")) }
            if item.isAppHidden { chip(symbol: "eye.slash", label: String(localized: "Hidden")) }
            if item.isFullScreen && !item.isOnScreen {
                chip(symbol: "arrow.up.left.and.arrow.down.right", label: String(localized: "Full Screen"))
            }
            if let space = item.otherSpace {
                chip(symbol: "square.on.square", label: String(localized: "Desktop \(space)"), text: "\(space)")
            }
        }
    }

    private func chip(symbol: String, label: String, text: String? = nil) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            if let text { Text(text).font(.system(size: 10, weight: .semibold)).monospacedDigit() }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(Capsule().fill(Theme.card.opacity(0.94)))
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A key as printed on a keyboard, for hints.
struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// Presses shrink a touch the moment the mouse goes down, not on release.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.harborPress, value: configuration.isPressed)
    }
}

/// The primary Harbor button: coral fill, cream text.
struct HarborButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                Capsule().fill(prominent ? Theme.coralText : Theme.card)
                    .overlay(Capsule().strokeBorder(prominent ? Color.clear : Theme.hairline))
            )
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.harborPress, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Fixed-size tiles in rows, with a short last row centred under the others
/// rather than hanging to the left.
struct TileGrid: Layout {
    var tile: CGSize
    var columns: Int
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let count = subviews.count
        guard count > 0 else { return .zero }
        let cols = min(columns, count)
        let rows = (count + columns - 1) / columns
        return CGSize(width: CGFloat(cols) * tile.width + CGFloat(cols - 1) * spacing,
                      height: CGFloat(rows) * tile.height + CGFloat(rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        for index in 0..<count {
            let row = index / columns
            let inRow = min(columns, count - row * columns)
            let rowWidth = CGFloat(inRow) * tile.width + CGFloat(inRow - 1) * spacing
            let x = bounds.minX + (bounds.width - rowWidth) / 2 + CGFloat(index % columns) * (tile.width + spacing)
            let y = bounds.minY + CGFloat(row) * (tile.height + spacing)
            subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(tile))
        }
    }
}
