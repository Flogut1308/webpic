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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Preset.all) { preset in
                    let on = store.activeSettings.preset == preset.key
                    Button { store.selectPreset(preset.key) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: gradient(preset.key).map { Color(hex: $0) },
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .padding(.bottom, 6)
                            Text(preset.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.t1)
                            Text(preset.sub).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
                        }
                        .frame(minWidth: 132, alignment: .leading)
                        .padding(12)
                        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(on ? p.accent : p.sep, lineWidth: on ? 1.5 : 0.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 3)
        }
    }
}
