import SwiftUI
import WebPicCore

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Ausgabe")
                        Picker("", selection: $store.settings.outputMode) {
                            Text("Einzelbild").tag(OutputMode.single)
                            Text("Responsive Set").tag(OutputMode.responsive)
                            Text("Nur Konvertierung").tag(OutputMode.convert)
                        }.pickerStyle(.segmented).labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Preset")
                        PresetCards(store: store)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Format")
                        FormatChips(store: store)
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 28).padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let img = store.selected {
                PreviewColumn(image: img, store: store)
                    .padding(Edge.Set.trailing, 28).padding(Edge.Set.top, 26)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.grouped)
    }
}
