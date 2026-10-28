import SwiftUI

/// The switcher: a calm cream surface with one tile per window. A ring in the
/// chosen highlight colour slides to the selection on a critically damped spring.
struct SwitcherView: View {
    @Bindable var model: SwitcherModel
    var thumbnails: ThumbnailCache
    var showsPictures: Bool
    /// Off only for the demo GIF, which draws the moving ring itself.
    var showsSelection = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection

    var body: some View {
        ZStack {
            // Clicking anywhere outside the surface cancels, like the Escape key.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.onCancel?() }

            // Shown and hidden by Core Animation on the panel's layer (see PanelMotion).
            surface
        }
    }

    private var surface: some View {
        let layout = model.layout
        let items = model.visibleItems
        return VStack(spacing: 14) {
            if model.isSearching { SearchField(query: model.query) }

            if items.isEmpty {
                EmptyState(isSearching: model.isSearching)
                    .frame(width: max(layout.gridWidth, 320), height: 120)
            } else {
                grid(items, layout: layout)
            }

            HintBar(isSearching: model.isSearching, showsPictures: showsPictures)
        }
        .padding(SwitcherLayout.padding)
        .background(HarborSurface(cornerRadius: 26))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .animation(reduceMotion ? nil : .harborPresent, value: layout)
    }

    @ViewBuilder
    private func grid(_ items: [WindowItem], layout: SwitcherLayout) -> some View {
        let content = TileGrid(tile: CGSize(width: layout.tileWidth, height: layout.tileHeight),
                               columns: layout.columns, spacing: SwitcherLayout.spacing) {
            ForEach(items) { item in
                Tile(item: item, image: showsPictures ? thumbnails.images[item.id] : nil, layout: layout,
                     isSelected: showsSelection && item.id == model.selectedItem?.id, selection: selection,
                     onHover: { select(item) }, onPress: { model.onCommit?(item) })
                    .id(item.id)
            }
        }
        .frame(width: layout.gridWidth)

        if layout.scrolls {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) { content }
                    .frame(height: layout.gridHeight)
                    .onChange(of: model.selectedID) { _, id in
                        withAnimation(reduceMotion ? nil : .harborSelect) { proxy.scrollTo(id) }
                    }
            }
        } else {
            content
        }
    }

    private func select(_ item: WindowItem) {
        guard model.selectedID != item.id else { return }
        withAnimation(reduceMotion ? nil : .harborSelect) { model.selectedID = item.id }
    }
}

private struct Tile: View {
    @Environment(\.palette) private var palette
    @Environment(\.accent) private var accent
    let item: WindowItem
    let image: CGImage?
    let layout: SwitcherLayout
    let isSelected: Bool
    let selection: Namespace.ID
    let onHover: () -> Void
    let onPress: () -> Void

    /// Where the pointer was when the panel appeared under it. Hover only
    /// selects once the pointer really moves, so a still mouse never steals
    /// the selection from the keyboard.
    @State private var restingPoint: CGPoint?

    var body: some View {
        Button(action: onPress) {
            VStack(spacing: 8) {
                WindowThumbnail(item: item, image: image, size: layout.thumbnailSize)
                HStack(spacing: 6) {
                    Image(nsImage: AppIcons.icon(for: item.pid))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(item.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.ink : palette.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(height: SwitcherLayout.captionHeight)
                // Text changes snap. Interpolating a font weight redraws every
                // glyph on every frame; only the ring needs to move.
                .transaction { $0.animation = nil }
                .frame(maxWidth: .infinity)
            }
            .padding(SwitcherLayout.tilePadding)
            .frame(width: layout.tileWidth, height: layout.tileHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(accent.color, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "selection", in: selection)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .onContinuousHover { phase in
            guard case .active(let point) = phase else { return }
            guard let start = restingPoint else { restingPoint = point; return }
            if hypot(point.x - start.x, point.y - start.y) > 3 { onHover() }
        }
        .accessibilityLabel("\(item.appName), \(item.displayTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SearchField: View {
    @Environment(\.palette) private var palette
    @Environment(\.accent) private var accent
    let query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.ink3)
            if query.isEmpty {
                Text("Type to search windows")
                    .foregroundStyle(palette.ink3)
            } else {
                Text(query).foregroundStyle(palette.ink)
            }
            RoundedRectangle(cornerRadius: 1).fill(accent.color).frame(width: 2, height: 18)
                .padding(.leading, query.isEmpty ? -8 : -6)
                .opacity(query.isEmpty ? 0 : 1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 17, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.hairline))
        .frame(maxWidth: 520)
    }
}

private struct EmptyState: View {
    @Environment(\.palette) private var palette
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isSearching ? "text.magnifyingglass" : "macwindow")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(palette.ink3)
            Text(isSearching ? "No matching windows" : "No open windows")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.ink2)
        }
    }
}

private struct HintBar: View {
    @Environment(\.palette) private var palette
    let isSearching: Bool
    let showsPictures: Bool

    var body: some View {
        HStack(spacing: 11) {
            if isSearching {
                hint("↩", "Open")
                hint("⇥", "Next")
                hint("esc", "Cancel")
            } else {
                hint("⇥", "Next")
                hint(String(localized: "space", comment: "Space bar keycap"), "Search")
                hint("W", "Close")
                hint("M", "Minimize")
                hint("Q", "Quit")
                hint("esc", "Cancel")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(palette.ink3)
    }

    private func hint(_ key: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Keycap(key: key, compact: true)
            Text(label)
        }
    }
}
