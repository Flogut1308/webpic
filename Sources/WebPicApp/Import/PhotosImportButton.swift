import SwiftUI
import PhotosUI
import WebPicCore

struct PhotosImportButton: View {
    @Environment(AppStore.self) private var store
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            Text("Aus Fotos importieren")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .onChange(of: selection) { _, items in
            let picked = items
            selection = []
            Task {
                var loaded: [(data: Data, name: String)] = []
                for (i, item) in picked.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append((data, "photo-\(i + 1).jpg"))
                    }
                }
                await store.importData(loaded)
            }
        }
    }
}
