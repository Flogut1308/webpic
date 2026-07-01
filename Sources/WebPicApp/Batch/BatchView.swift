import SwiftUI
import WebPicCore

struct BatchView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alle gleich behandeln").font(.system(size: 14, weight: .semibold))
                        Text(store.sameForAll ? "Ein Setting für alle Bilder" : "Jedes Bild einzeln einstellbar")
                            .font(.system(size: 12)).foregroundStyle(p.t3)
                    }
                    Toggle("", isOn: $store.sameForAll).labelsHidden().toggleStyle(.switch).tint(p.accent)
                    Rectangle().fill(p.sep).frame(width: 0.5, height: 26)
                    Button("Alle entfernen") { store.clearAll() }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).wpCard(p)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.images) { img in
                        BatchCard(image: img, onRemove: { store.remove(id: img.id) })
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(p.grouped)
        .task(id: batchKey) { await store.processAll() }
    }

    private var batchKey: String {
        store.images.map(\.id).joined(separator: ",") + "|" + store.settings.hashValueString
    }
}
