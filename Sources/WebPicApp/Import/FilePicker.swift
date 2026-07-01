import AppKit
import WebPicCore

enum FilePicker {
    @MainActor
    static func pickImages() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ImageImportService.supportedTypes
        panel.prompt = "Importieren"
        panel.message = "Bilder zum Optimieren auswählen"
        return panel.runModal() == .OK ? panel.urls : []
    }
}
