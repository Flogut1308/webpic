import SwiftUI
import AppKit

@main
struct WebPicMain: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }
    var body: some Scene {
        WindowGroup("WebPic") {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
    }
}
