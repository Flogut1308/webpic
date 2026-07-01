import SwiftUI
import WebPicCore

struct RootView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemScheme

    private var effectiveScheme: ColorScheme {
        switch theme.appearance {
        case .system: return systemScheme
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    private var palette: WPPalette { effectiveScheme == .dark ? .dark : .light }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(250)
        } detail: {
            MainView()
        }
        .environment(\.wpPalette, palette)
        .preferredColorScheme(theme.preferredColorScheme)
        .tint(.blue)
        .screenshotWindowFix()
        .overlay {
            if store.sheet == .code {
                CodeSheet(store: store).environment(\.wpPalette, palette)
            }
        }
    }
}
