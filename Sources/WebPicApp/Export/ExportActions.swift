import AppKit
import WebPicCore

enum ExportActions {
    @MainActor static func pickDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Hier speichern"
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor static func share(_ results: [EncodeResult]) {
        guard let first = results.first else { return }
        let name = FilenameFormatter.expand("{name}-{w}.{format}", name: "image", width: first.width, format: first.format)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? first.data.write(to: tmp)
        let picker = NSSharingServicePicker(items: [tmp])
        if let win = NSApp.keyWindow, let view = win.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
}
