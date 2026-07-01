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
        _store = State(initialValue: store)
        _theme = State(initialValue: theme)
    }

    var body: some Scene {
        WindowGroup("WebPic") {
            RootView()
                .environment(store)
                .environment(theme)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
    }
}
