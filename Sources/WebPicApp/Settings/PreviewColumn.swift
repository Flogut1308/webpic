import SwiftUI
import WebPicCore

struct PreviewColumn: View {
    let image: WebPicImage
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private var estBytes: Int { EstimationService.estimatedBytes(image: image, settings: store.activeSettings) }
    private var savings: Int { EstimationService.savingsPercent(image: image, settings: store.activeSettings) }
    private var newDims: (width: Int, height: Int) { EstimationService.newDimensions(image: image, settings: store.activeSettings) }

    // Selected formats in display order, each with its own estimate (multi-format breakdown).
    private let formatOrder: [ImageFormat] = [.avif, .webp, .jpeg, .png]
    private var selectedFormats: [ImageFormat] {
        formatOrder.filter { store.activeSettings.formats.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ThumbnailView(image: image, cornerRadius: 0)
                .frame(maxWidth: .infinity).frame(height: 210).clipped()
                .overlay(alignment: .topLeading) {
                    Text("VORSCHAU").font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white).padding(10)
                }
            VStack(alignment: .leading, spacing: 0) {
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
                    Text("−\(savings)%").font(.system(size: 26, weight: .semibold).monospacedDigit())
                    Text("kleiner · spart \(formatBytes(max(0, image.byteSize - estBytes)))").font(.system(size: 12)).foregroundStyle(p.t2)
                }
                .padding(.bottom, 14)
                Divider()
                row("Auflösung", "\(image.pixelWidth)×\(image.pixelHeight) → \(newDims.width)×\(newDims.height)", mono: true)
                formatBreakdown
            }
            .padding(.horizontal, 15).padding(.top, 14).padding(.bottom, 16)
        }
        .wpCard(p)
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 460)
    }

    // Per-format estimated sizes, so choosing several formats shows what each will weigh.
    @ViewBuilder private var formatBreakdown: some View {
        if selectedFormats.isEmpty {
            row("Format", "—", mono: false)
        } else if selectedFormats.count == 1 {
            row("Format", selectedFormats[0].displayName, mono: false)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("Formate").font(.system(size: 12)).foregroundStyle(p.t2)
                    Spacer()
                }.padding(.top, 8)
                ForEach(selectedFormats, id: \.self) { fmt in
                    HStack {
                        Text(fmt.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(p.t1)
                        Spacer()
                        Text(formatBytes(EstimationService.estimatedBytes(image: image, settings: store.activeSettings, format: fmt)))
                            .font(.system(size: 12).monospacedDigit()).foregroundStyle(p.t2)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    @ViewBuilder private func row(_ label: String, _ value: String, mono: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(p.t2)
            Spacer()
            Text(value).font(mono ? .system(size: 12).monospacedDigit() : .system(size: 12, weight: .medium)).foregroundStyle(p.t1)
        }
        .padding(.top, 8)
    }
}
