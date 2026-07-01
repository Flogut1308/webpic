import SwiftUI
import WebPicCore

struct PresetCards: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private func gradient(_ key: Preset.Key) -> [UInt32] {
        switch key {
        case .hero:    return [0x0A84FF, 0x5E5CE6]
        case .content: return [0x30D158, 0x0FB5AE]
        case .thumb:   return [0xFF9F0A, 0xFF375F]
        case .icon:    return [0xBF5AF2, 0x5E5CE6]
        case .custom:  return [0x8E8E93, 0x636366]
        }
    }

    // Wrapping grid so every preset stays visible when there's room, instead of scrolling off-screen.
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(Preset.all) { preset in
                    card(preset)
                }
            }
            if store.activeSettings.preset == .custom {
                customWidthField
            }
        }
        .padding(.horizontal, 2).padding(.vertical, 3)
    }

    @ViewBuilder private func card(_ preset: Preset) -> some View {
        let on = store.activeSettings.preset == preset.key
        Button { store.selectPreset(preset.key) } label: {
            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: gradient(preset.key).map { Color(hex: $0) },
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .padding(.bottom, 6)
                Text(preset.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.t1)
                    .lineLimit(1)
                Text(preset.sub).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(on ? p.accent : p.sep, lineWidth: on ? 1.5 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customWidthField: some View {
        HStack(spacing: 10) {
            Text("Zielbreite").font(.system(size: 13)).foregroundStyle(p.t2)
            TextField("1600", text: widthText)
                .textFieldStyle(.plain).font(.system(size: 14, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 74, height: 30).padding(.horizontal, 10)
                .background(p.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(p.ctrlBorder, lineWidth: 1))
            Text("px").font(.system(size: 13)).foregroundStyle(p.t3)
            if let img = store.selected {
                let d = EstimationService.newDimensions(image: img, settings: store.activeSettings)
                Text("→ \(d.width) × \(d.height) px").font(.system(size: 12).monospacedDigit()).foregroundStyle(p.t3)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.sep, lineWidth: 0.5))
    }

    // Height follows the source aspect automatically, so only width is editable.
    private var widthText: Binding<String> {
        Binding(
            get: { store.activeSettings.customWidth.map(String.init) ?? "" },
            set: { store.activeSettings.customWidth = Int($0.filter(\.isNumber)) }
        )
    }
}
