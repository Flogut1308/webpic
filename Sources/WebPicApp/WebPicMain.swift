import SwiftUI
import AppKit
import WebPicCore

@main
struct WebPicMain: App {
    @State private var store = AppStore()
    @State private var theme = ThemeManager()

    init() { NSApplication.shared.setActivationPolicy(.regular) }

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
