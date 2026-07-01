import SwiftUI
import WebPicCore

struct SettingsPlaceholderView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.wpPalette) private var p
    var body: some View {
        VStack(spacing: 8) {
            Text(store.selected?.name ?? "—").font(.system(size: 17, weight: .semibold))
            Text("Einstellungen folgen in Meilenstein 3").foregroundStyle(p.t3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.grouped)
    }
}
