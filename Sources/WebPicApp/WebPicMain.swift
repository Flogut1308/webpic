import SwiftUI
import AppKit
import WebPicCore

@main
struct WebPicMain: App {
    @State private var store: AppStore
    @State private var theme: ThemeManager

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        let store = AppStore()
        let theme = ThemeManager()
        // Screenshot/testing hooks: pre-seed and force appearance for deterministic captures.
        let env = ProcessInfo.processInfo.environment
        if env["WEBPIC_SEED"] == "1" { store.seedMockImages() }
        switch env["WEBPIC_APPEARANCE"] {
        case "light": theme.appearance = .light
        case "dark":  theme.appearance = .dark
        default:      break
        }
        // Apply WEBPIC_TAB by assigning store.tab directly (resolves via the property's
        // type; the bare `Tab` name is ambiguous with SwiftUI.Tab and the WebPicCore enum).
        let tabEnv = env["WEBPIC_TAB"]
        let sheetEnv = env["WEBPIC_SHEET"]
        let applyOverrides: () -> Void = {
            switch tabEnv {
            case "compare": store.tab = .compare
            case "export":  store.tab = .export
            case "batch":   store.tab = .batch
            default:        break
            }
            switch sheetEnv {
            case "code":   store.sheet = .code
            case "update": store.sheet = .update
            default:       break
            }
        }
        if let paths = env["WEBPIC_IMPORT"], !paths.isEmpty {
            let urls = paths.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
            // Apply overrides AFTER import — importFiles resets tab to .settings on completion.
            Task { await store.importFiles(urls); applyOverrides() }
        } else {
            applyOverrides()
        }
        if env["WEBPIC_UPDATE"] == "1" {
            store.availableUpdate = ReleaseInfo(
                version: "2.1",
                notes: ["AVIF-Encoder um bis zu 3× schneller",
                        "Neues Next.js-Snippet mit sizes",
                        "Fehler beim Beibehalten von EXIF behoben"],
                downloadURL: URL(string: "https://github.com/Flogut1308/webpic/releases/latest")!,
                sizeBytes: 14_680_064)
            store.showUpdate = true
        } else {
            Task { await store.checkForUpdate() }
        }
        _store = State(initialValue: store)
        _theme = State(initialValue: theme)
    }

    var body: some Scene {
        WindowGroup("WebPic") {
            RootView()
                .environment(store)
                .environment(theme)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1240, height: 820)
    }
}
