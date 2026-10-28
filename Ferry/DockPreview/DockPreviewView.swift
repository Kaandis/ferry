import SwiftUI

/// An app's windows, grown out of its Dock icon.
struct DockPreviewView: View {
    @Environment(\.palette) private var palette
    @Bindable var model: DockPreviewModel
    var thumbnails: ThumbnailCache
    var showsPictures: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(nsImage: AppIcons.icon(for: model.pid))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(model.appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.ink)
                Text("\(model.items.count) windows")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink3)
            }
            .frame(height: DockPreviewMetrics.header)
            .padding(.leading, 4)

            if rows > DockPreviewMetrics.maxRows {
                ScrollView(.vertical, showsIndicators: false) { cards }
                    .frame(height: CGFloat(DockPreviewMetrics.maxRows) * DockPreviewMetrics.cardHeight
                           + CGFloat(DockPreviewMetrics.maxRows - 1) * DockPreviewMetrics.spacing)
            } else {
                cards
            }
        }
        .padding(DockPreviewMetrics.padding)
        .background(HarborSurface(cornerRadius: 20))
        .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
        .onHover { inside in if !inside { model.onPointerExit?() } }
        // It grows out of the Dock and returns into it along the same path,
        // driven by Core Animation on the panel's layer (see PanelMotion).
    }

    private var rows: Int { (model.items.count + model.columns - 1) / max(1, model.columns) }

    private var cards: some View {
        TileGrid(tile: CGSize(width: DockPreviewMetrics.cardWidth, height: DockPreviewMetrics.cardHeight),
                 columns: max(1, model.columns), spacing: DockPreviewMetrics.spacing) {
            ForEach(model.items) { item in
                Card(item: item, image: showsPictures ? thumbnails.images[item.id] : nil,
                     isHovered: model.hoveredID == item.id,
                     onHover: { hovering in
                         withAnimation(reduceMotion ? nil : .harborSelect) {
                             if hovering { model.hoveredID = item.id } else if model.hoveredID == item.id { model.hoveredID = nil }
                         }
                     },
                     onOpen: { model.onOpen?(item) },
                     onClose: { model.onClose?(item) })
            }
        }
    }
}

private struct Card: View {
    @Environment(\.palette) private var palette
    let item: WindowItem
    let image: CGImage?
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 6) {
                WindowThumbnail(item: item, image: image, size: DockPreviewMetrics.thumbnail)
                Text(item.displayTitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(isHovered ? palette.ink : palette.ink2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(height: 16)
                    .transaction { $0.animation = nil }
            }
            .padding(DockPreviewMetrics.cardPadding)
            .frame(width: DockPreviewMetrics.cardWidth, height: DockPreviewMetrics.cardHeight)
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.coral, lineWidth: 2))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .overlay(alignment: .topLeading) {
            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(palette.card))
                        .overlay(Circle().strokeBorder(palette.hairline))
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                }
                .buttonStyle(PressableStyle())
                .help(String(localized: "Close Window"))
                .offset(x: 2, y: 2)
                .transition(.opacity)
            }
        }
        .onHover(perform: onHover)
        .accessibilityLabel("\(item.appName), \(item.displayTitle)")
    }
}
