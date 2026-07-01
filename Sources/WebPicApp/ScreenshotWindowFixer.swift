import SwiftUI
import AppKit

/// Screenshot/testing helper: when any `WEBPIC_*` launch var is set, pin the window to a
/// fixed on-screen frame. Headless raw-binary launches otherwise cascade off-screen after
/// repeated runs, which breaks window-targeted `screencapture`. No effect in normal use.
struct ScreenshotWindowFixer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let win = v.window else { return }
            win.setFrame(NSRect(x: 120, y: 120, width: 1240, height: 820), display: true)
            win.makeKeyAndOrderFront(nil)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Applies the window pinner only in screenshot mode (a `WEBPIC_*` env var present).
    @ViewBuilder func screenshotWindowFix() -> some View {
        let env = ProcessInfo.processInfo.environment
        let active = env["WEBPIC_TAB"] != nil || env["WEBPIC_IMPORT"] != nil
            || env["WEBPIC_SHEET"] != nil || env["WEBPIC_SEED"] != nil || env["WEBPIC_APPEARANCE"] != nil
        if active {
            self.background(ScreenshotWindowFixer())
        } else {
            self
        }
    }
}
