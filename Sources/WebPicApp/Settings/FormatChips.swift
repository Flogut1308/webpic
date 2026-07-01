import SwiftUI
import WebPicCore

struct FormatChips: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private let defs: [(ImageFormat, String)] =
        [(.webp, "WebP"), (.avif, "AVIF"), (.jpeg, "JPEG-Fallback"), (.png, "PNG")]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(defs, id: \.0) { fmt, label in
                let on = store.settings.formats.contains(fmt)
                Button { store.toggleFormat(fmt) } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(on ? p.accent : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(on ? p.accent : p.ctrlBorder, lineWidth: 1.5))
                            .frame(width: 15, height: 15)
                            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) } }
                        Text(label).font(.system(size: 13, weight: on ? .medium : .regular))
                            .foregroundStyle(on ? p.accent : p.t1)
                    }
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(on ? p.accentTint : p.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(on ? p.accent : p.sep2, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
