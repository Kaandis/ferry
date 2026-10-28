import AppKit
import HarborKit
import SwiftUI

/// A window's picture, or its app icon on a soft card when there's no picture
/// (no Screen Recording permission, or a minimized window seen for the first time).
struct WindowThumbnail: View {
    @Environment(\.palette) private var palette
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
                    .fill(palette.raised)
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
    @Environment(\.palette) private var palette
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
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(Capsule().fill(palette.card.opacity(0.94)))
        .overlay(Capsule().strokeBorder(palette.hairline))
        .help(label)
        .accessibilityLabel(label)
    }
}
