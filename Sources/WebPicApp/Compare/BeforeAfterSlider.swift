import SwiftUI
import AppKit

struct BeforeAfterSlider: View {
    let before: NSImage
    let after: NSImage
    var caption: String? = nil          // e.g. "AVIF · Q80" — what the "Optimiert" side is

    @State private var fraction: CGFloat = 0.5
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var fractionDragStart: CGFloat?
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGSize = .zero
    @Environment(\.wpPalette) private var p

    private let maxScale: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let liveScale = clampScale(scale * gestureZoom)
            let zoomed = liveScale > 1.01
            let liveOffset = clampOffset(add(offset, gesturePan), scale: liveScale, size: geo.size)
            let cx = geo.size.width / 2
            // Screen-space x of the split, derived from the same transform the images use, so the
            // handle stays on the seam — and stays draggable — even while zoomed and panned.
            let dividerX = cx + (fraction * geo.size.width - cx) * liveScale + liveOffset.width

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Image(nsImage: after).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                    Image(nsImage: before).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * fraction) }
                }
                .scaleEffect(liveScale).offset(liveOffset)

                // Split line + handle, in screen space, always draggable.
                Rectangle().fill(.white).frame(width: 2, height: geo.size.height)
                    .position(x: dividerX, y: geo.size.height / 2).shadow(radius: 1)
                Circle().fill(.white).frame(width: 34, height: 34).shadow(radius: 3)
                    .overlay { Image(systemName: "chevron.left.chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent) }
                    .position(x: dividerX, y: geo.size.height / 2)
                    .highPriorityGesture(DragGesture()
                        .onChanged { v in
                            let start = fractionDragStart ?? fraction
                            if fractionDragStart == nil { fractionDragStart = fraction }
                            fraction = max(0, min(1, start + v.translation.width / (geo.size.width * liveScale)))
                        }
                        .onEnded { _ in fractionDragStart = nil })

                pill("Original", bg: .black.opacity(0.5), align: .topLeading)
                pill(caption.map { "Optimiert · \($0)" } ?? "Optimiert", bg: p.accent.opacity(0.9), align: .topTrailing)
                zoomControls(liveScale: liveScale, zoomed: zoomed)
            }
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(ScrollZoom { dy in
                scale = clampScale(scale * (1 + dy * 0.0025))
                if scale <= 1.01 { scale = 1; offset = .zero }
            })
            .gesture(MagnificationGesture()
                .updating($gestureZoom) { v, s, _ in s = v }
                .onEnded { v in scale = clampScale(scale * v); if scale <= 1.01 { scale = 1; offset = .zero } })
            .gesture(DragGesture(minimumDistance: 0)
                .updating($gesturePan) { v, s, _ in if zoomed { s = v.translation } }
                .onChanged { v in if !zoomed { fraction = max(0, min(1, v.location.x / geo.size.width)) } }
                .onEnded { v in if zoomed { offset = clampOffset(add(offset, v.translation), scale: scale, size: geo.size) } })
            .onTapGesture(count: 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if zoomed { scale = 1; offset = .zero } else { scale = detailScale(geo: geo) }
                }
            }
        }
    }

    // MARK: chrome

    @ViewBuilder private func pill(_ text: String, bg: Color, align: Alignment) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
            .background(bg, in: Capsule()).foregroundStyle(.white).padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
    }

    private func zoomControls(liveScale: CGFloat, zoomed: Bool) -> some View {
        HStack(spacing: 2) {
            zoomButton("minus") { setScale(scale - 0.5) }
            Text(String(format: "%.1f×", liveScale)).font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white).frame(width: 40)
            zoomButton("plus") { setScale(scale + 0.5) }
            if zoomed {
                Divider().frame(height: 16).overlay(.white.opacity(0.3))
                zoomButton("arrow.counterclockwise") { withAnimation(.easeOut(duration: 0.2)) { scale = 1; offset = .zero } }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func zoomButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white).frame(width: 22, height: 22).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    // MARK: math

    private func setScale(_ v: CGFloat) {
        withAnimation(.easeOut(duration: 0.15)) {
            scale = clampScale(v)
            if scale <= 1.01 { scale = 1; offset = .zero }
        }
    }
    private func clampScale(_ v: CGFloat) -> CGFloat { min(max(v, 1), maxScale) }
    private func add(_ a: CGSize, _ b: CGSize) -> CGSize { CGSize(width: a.width + b.width, height: a.height + b.height) }
    private func clampOffset(_ o: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
        guard scale > 1 else { return .zero }
        let mx = size.width * (scale - 1) / 2, my = size.height * (scale - 1) / 2
        return CGSize(width: min(max(o.width, -mx), mx), height: min(max(o.height, -my), my))
    }
    private func detailScale(geo: GeometryProxy) -> CGFloat {
        let px = CGFloat(after.representations.first?.pixelsWide ?? Int(after.size.width))
        guard geo.size.width > 0, px > 0 else { return 3 }
        return clampScale(max(2, px / geo.size.width))
    }
}

/// Captures scroll-wheel / trackpad two-finger scroll to drive zoom. Sits behind the images so it
/// only sees events the SwiftUI content didn't consume; the ± buttons cover mice without wheels.
private struct ScrollZoom: NSViewRepresentable {
    let onZoom: (CGFloat) -> Void
    func makeNSView(context: Context) -> NSView { let v = Catcher(); v.onZoom = onZoom; return v }
    func updateNSView(_ nsView: NSView, context: Context) { (nsView as? Catcher)?.onZoom = onZoom }

    final class Catcher: NSView {
        var onZoom: ((CGFloat) -> Void)?
        override func scrollWheel(with e: NSEvent) {
            let dy = e.hasPreciseScrollingDeltas ? e.scrollingDeltaY : e.scrollingDeltaY * 4
            if dy != 0 { onZoom?(dy) }
        }
    }
}
