import SwiftUI
import WebPicCore

private struct WPPaletteKey: EnvironmentKey {
    static let defaultValue: WPPalette = .light
}

extension EnvironmentValues {
    var wpPalette: WPPalette {
        get { self[WPPaletteKey.self] }
        set { self[WPPaletteKey.self] = newValue }
    }
}
