import AppKit
import Observation

/// What the switcher panel shows: the windows, the selection and the search.
@MainActor
@Observable
final class SwitcherModel {
    var items: [WindowItem] = []
    var selectedID: CGWindowID?
    var query = ""
    var isSearching = false
    /// True from the moment the panel is ordered in until its exit settles.
    var isPresented = false
    /// Visible area of the display the switcher opens on; tiles are sized to it.
    var screenSize: CGSize = .zero

    var layout: SwitcherLayout { SwitcherLayout(count: max(1, visibleItems.count), bounds: screenSize) }

    @ObservationIgnored var onCommit: ((WindowItem) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?

    var visibleItems: [WindowItem] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return items }
        return items.filter {
            $0.title.localizedStandardContains(needle) || $0.appName.localizedStandardContains(needle)
        }
    }

    var selectedItem: WindowItem? {
        visibleItems.first { $0.id == selectedID } ?? visibleItems.first
    }

    func move(by offset: Int) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selectedID } ?? 0
        let count = list.count
        selectedID = list[((current + offset) % count + count) % count].id
    }

    func selectFirstMatch() {
        selectedID = visibleItems.first?.id
    }

    func reset() {
        items = []
        selectedID = nil
        query = ""
        isSearching = false
    }
}

/// Tile size and grid shape for a number of windows inside the available
/// area. Tiles shrink before the grid scrolls, so most setups see every
/// window at once.
struct SwitcherLayout: Equatable {
    var tileWidth: CGFloat = 232
    var columns = 1
    var rows = 1
    /// Rows on screen at once; fewer than `rows` when the grid scrolls.
    var visibleRows = 1
    var scrolls = false

    static let spacing: CGFloat = 10
    static let padding: CGFloat = 18
    static let tilePadding: CGFloat = 10
    static let captionHeight: CGFloat = 18
    static let maxTile: CGFloat = 232
    static let minTile: CGFloat = 164

    var thumbnailSize: CGSize {
        let width = tileWidth - Self.tilePadding * 2
        return CGSize(width: width, height: (width * 0.62).rounded())
    }

    var tileHeight: CGFloat { Self.tilePadding * 2 + thumbnailSize.height + 8 + Self.captionHeight }

    init(count: Int, bounds: CGSize) {
        guard count > 0, bounds.width > 0 else { return }
        let maxWidth = bounds.width * 0.9 - Self.padding * 2
        let maxHeight = bounds.height * 0.72 - Self.padding * 2
        var width = Self.maxTile
        while true {
            tileWidth = width
            columns = max(1, min(count, Int((maxWidth + Self.spacing) / (width + Self.spacing))))
            rows = Int((Double(count) / Double(columns)).rounded(.up))
            let height = CGFloat(rows) * tileHeight + CGFloat(rows - 1) * Self.spacing
            if height <= maxHeight { visibleRows = rows; return }
            if width <= Self.minTile {
                scrolls = true
                visibleRows = max(1, Int((maxHeight + Self.spacing) / (tileHeight + Self.spacing)))
                return
            }
            width = max(Self.minTile, width - 12)
        }
    }

    /// Height of the grid area, capped to what fits when it scrolls.
    var gridHeight: CGFloat {
        let shown = CGFloat(visibleRows)
        return shown * tileHeight + max(0, shown - 1) * Self.spacing
    }

    var gridWidth: CGFloat { CGFloat(columns) * tileWidth + CGFloat(columns - 1) * Self.spacing }
}
