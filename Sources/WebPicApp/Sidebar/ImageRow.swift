import SwiftUI
import WebPicCore

struct ImageRow: View {
    @Environment(\.wpPalette) private var p
    let image: WebPicImage
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                GradientSwatch(hexes: image.gradient)
                    .frame(width: 34, height: 34)
                    .overlay {
                        if case .processing = image.status {
                            ProgressView().controlSize(.small).tint(.white)
                        } else if case .error = image.status {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.white).font(.system(size: 13, weight: .bold))
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(image.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? p.accent : p.t1)
                        .lineLimit(1).truncationMode(.tail)
                    Text("\(image.pixelWidth)×\(image.pixelHeight) · \(formatBytes(image.byteSize))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(p.t3)
                }
                Spacer(minLength: 4)
                Circle().fill(statusColor(image.status, p)).frame(width: 8, height: 8)
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain).foregroundStyle(p.t3)
                    .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 7).padding(.horizontal, 9)
            .background(isSelected ? p.accentTint : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
