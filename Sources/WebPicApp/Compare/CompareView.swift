import SwiftUI
import AppKit
import WebPicCore

struct CompareView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private var image: WebPicImage? { store.selected }
    private var result: EncodeResult? { store.primaryResult }
    private var beforeImage: NSImage? {
        guard let img = image else { return nil }
        // Downsampled + cached (max 1600px) so the full-res original isn't decoded per redraw.
        return ThumbnailCache.downsampled(id: img.id, url: img.url, data: img.sourceData)
            ?? img.thumbnailData.flatMap(NSImage.init(data:))
    }
    private var afterImage: NSImage? { result.flatMap { NSImage(data: $0.data) } }

    var body: some View {
        VStack(spacing: 20) {
            if store.processing {
                ProgressView("Optimiere …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let img = image, let before = beforeImage, let after = afterImage, let r = result {
                BeforeAfterSlider(before: before, after: after)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 14) {
                    metric("Größenersparnis", "−\(savings(img, r))%", sub: "\(formatBytes(img.byteSize)) → \(formatBytes(r.byteSize))")
                    metric("Gespart", formatBytes(max(0, img.byteSize - r.byteSize)), sub: nil)
                    metric("Neue Auflösung", "\(r.width)×\(r.height)", sub: nil)
                }
            } else {
                Text("Keine Vorschau verfügbar").foregroundStyle(p.t3).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(p.grouped)
        .task(id: "\(store.selectedID ?? "")-\(store.selected.map { store.effectiveSettings(for: $0).hashValueString } ?? "")") { await store.processSelected() }
    }

    private func savings(_ img: WebPicImage, _ r: EncodeResult) -> Int {
        img.byteSize > 0 ? max(0, Int((1 - Double(r.byteSize)/Double(img.byteSize)) * 100)) : 0
    }

    @ViewBuilder private func metric(_ title: String, _ value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(p.t2)
            Text(value).font(.system(size: 28, weight: .semibold).monospacedDigit())
            if let sub { Text(sub).font(.system(size: 13).monospacedDigit()).foregroundStyle(p.t2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).wpCard(p)
    }
}
