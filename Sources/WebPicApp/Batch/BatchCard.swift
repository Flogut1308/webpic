import SwiftUI
import WebPicCore

struct BatchCard: View {
    let image: WebPicImage
    let onRemove: () -> Void
    @Environment(\.wpPalette) private var p

    private var statusLabel: String {
        switch image.status {
        case .waiting: return "Wartet"
        case .processing: return "Verarbeitet …"
        case .done: return "Fertig"
        case .error: return "Fehler"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                ThumbnailView(image: image, cornerRadius: 0).frame(height: 118).frame(maxWidth: .infinity).clipped()
                if case .processing = image.status {
                    ProgressView().controlSize(.small).tint(.white)
                } else if case .error = image.status {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 26)).foregroundStyle(.white)
                }
                Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .frame(width: 24, height: 24).background(.black.opacity(0.42), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(9)
                if case .done = image.status {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(p.statusDone, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(9)
                }
            }
            .frame(height: 118).clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(image.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text("\(image.pixelWidth)×\(image.pixelHeight) · \(formatBytes(image.byteSize))")
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
                HStack(spacing: 5) {
                    Circle().fill(statusColor(image.status, p)).frame(width: 7, height: 7)
                    Text(statusLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(statusColor(image.status, p))
                }.padding(.top, 8)
            }
            .padding(.horizontal, 12).padding(.vertical, 11).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.sep, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
