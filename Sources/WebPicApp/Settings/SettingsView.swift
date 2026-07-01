import SwiftUI
import AppKit
import WebPicCore

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    // Preview panel width — user-resizable via the splitter, remembered across launches.
    @AppStorage("wp.previewPanelWidth") private var panelWidth: Double = 300
    private let minPanel: Double = 240, maxPanel: Double = 440

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Ausgabe")
                        Picker("", selection: $store.activeSettings.outputMode) {
                            Text("Einzelbild").tag(OutputMode.single)
                            Text("Responsive Set").tag(OutputMode.responsive)
                            Text("Nur Konvertierung").tag(OutputMode.convert)
                        }.pickerStyle(.segmented).labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Preset")
                        PresetCards(store: store)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Format")
                        FormatChips(store: store)
                    }
                    if let img = store.selected {
                        CompressionCard(store: store, image: img)
                    }
                    if store.activeSettings.outputMode == .responsive {
                        BreakpointsCard(store: store)
                    }
                    AdvancedCard(store: store)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 28).padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(p.grouped)

            if let img = store.selected {
                PanelSplitter(width: $panelWidth, min: minPanel, max: maxPanel).environment(\.wpPalette, p)
                ScrollView {
                    PreviewColumn(image: img, store: store).padding(16)
                }
                .frame(width: panelWidth)
                .frame(maxHeight: .infinity)
                .background(p.window)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A draggable vertical splitter to resize the preview panel — the usual "drag the edge" affordance.
private struct PanelSplitter: View {
    @Binding var width: Double
    let min: Double
    let max: Double
    @Environment(\.wpPalette) private var p
    @State private var dragStart: Double?
    @State private var hovering = false

    var body: some View {
        Rectangle().fill(p.sep)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay {
                Rectangle().fill(hovering ? p.accent.opacity(0.35) : .clear).frame(width: 3)
            }
            .contentShape(Rectangle().inset(by: -5))   // wider hit area than the visible hairline
            .onHover { inside in
                hovering = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { v in
                    let base = dragStart ?? width
                    if dragStart == nil { dragStart = width }
                    // Dragging left widens the panel, right narrows it.
                    width = Swift.min(Swift.max(base - Double(v.translation.width), min), max)
                }
                .onEnded { _ in dragStart = nil })
    }
}
