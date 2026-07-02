import SwiftUI
import AppKit
import WebPicCore

struct PreviewColumn: View {
    let image: WebPicImage
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private var estBytes: Int { EstimationService.estimatedBytes(image: image, settings: store.activeSettings) }
    private var savings: Int { EstimationService.savingsPercent(image: image, settings: store.activeSettings) }
    private var newDims: (width: Int, height: Int) { EstimationService.newDimensions(image: image, settings: store.activeSettings) }

    // A high-res downsample (max 1600px) so the preview looks crisp instead of a tiny thumbnail.
    private var previewImage: NSImage? {
        ThumbnailCache.downsampled(id: image.id, url: image.url, data: image.sourceData)
    }

    private let formatOrder: [ImageFormat] = [.avif, .webp, .jpeg, .png]
    private var selectedFormats: [ImageFormat] {
        formatOrder.filter { store.activeSettings.formats.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let ns = previewImage {
                    Image(nsImage: ns).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ThumbnailView(image: image, cornerRadius: 0)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 200).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text("VORSCHAU").font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white).padding(10)
            }
            .padding(.bottom, 16)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Original").font(.system(size: 11)).foregroundStyle(p.t3)
                    Text(formatBytes(image.byteSize)).font(.system(size: 14, weight: .medium).monospacedDigit())
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(p.t3).font(.system(size: 13, weight: .semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Optimiert").font(.system(size: 11)).foregroundStyle(p.accent)
                    Text(formatBytes(estBytes)).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(p.accent)
                }
            }
            .padding(.bottom, 12)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.seg)
                    Capsule().fill(LinearGradient(colors: [p.accent, Color(hex: 0x5AC8FA)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(savings) / 100)
                }
            }
            .frame(height: 8).padding(.bottom, 8)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("−\(savings)%").font(.system(size: 26, weight: .semibold).monospacedDigit()).fixedSize()
                Text("kleiner · spart \(formatBytes(max(0, image.byteSize - estBytes)))")
                    .font(.system(size: 12)).foregroundStyle(p.t2).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)
            Divider()
            row("Auflösung", "\(image.pixelWidth)×\(image.pixelHeight) → \(newDims.width)×\(newDims.height)", mono: true)
            formatBreakdown
        }
    }

    @ViewBuilder private var formatBreakdown: some View {
        if selectedFormats.isEmpty {
            row("Format", "—", mono: false)
        } else if selectedFormats.count == 1 {
            row("Format", selectedFormats[0].displayName, mono: false)
        } else {
            VStack(spacing: 0) {
                HStack { Text("Formate").font(.system(size: 12)).foregroundStyle(p.t2); Spacer() }.padding(.top, 8)
                ForEach(selectedFormats, id: \.self) { fmt in
                    HStack {
                        Text(fmt.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(p.t1).fixedSize()
                        Spacer(minLength: 8)
                        Text(formatBytes(EstimationService.estimatedBytes(image: image, settings: store.activeSettings, format: fmt)))
                            .font(.system(size: 12).monospacedDigit()).foregroundStyle(p.t2).lineLimit(1)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    @ViewBuilder private func row(_ label: String, _ value: String, mono: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(p.t2).fixedSize()
            Spacer(minLength: 8)
            // Shrink long values (e.g. the resolution) rather than overflowing and clipping the
            // panel's right padding when it's narrow.
            Text(value).font(mono ? .system(size: 12).monospacedDigit() : .system(size: 12, weight: .medium))
                .foregroundStyle(p.t1).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.top, 8)
    }
}
