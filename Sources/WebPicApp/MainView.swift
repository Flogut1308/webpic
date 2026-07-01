import SwiftUI
import WebPicCore

struct MainView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.wpPalette) private var p

    var body: some View {
        Group {
            if store.isEmpty {
                EmptyImportView()
            } else if store.tab == .compare {
                CompareView(store: store)
            } else if store.tab == .export {
                ExportView(store: store)
            } else if store.tab == .batch {
                BatchView(store: store)
            } else {
                SettingsView(store: store)
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle("")
        .dropDestination(for: URL.self) { urls, _ in
            Task { await store.importFiles(urls) }
            return !urls.isEmpty
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !store.isEmpty {
            ToolbarItem(placement: .navigation) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.tab == .batch ? "Alle Bilder" : (store.selected?.name ?? "WebPic"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
                }
            }
            if store.tab != .batch {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: Binding(
                        get: { store.tab == .compare ? 1 : 0 },
                        set: { store.tab = $0 == 1 ? .compare : .settings })) {
                        Text("Einstellungen").tag(0)
                        Text("Vergleich").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { store.sheet = .code } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                    Button { store.tab = .export } label: {
                        Label("Exportieren", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent).tint(p.accent)
                }
            }
        }
    }

    private var subtitle: String {
        if store.tab == .batch { return "\(store.images.count) Bilder" }
        guard let im = store.selected else { return "Bereit zum Import" }
        return "\(im.pixelWidth)×\(im.pixelHeight) · \(formatBytes(im.byteSize))"
    }
}
