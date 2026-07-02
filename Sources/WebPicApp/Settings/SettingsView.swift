import SwiftUI
import AppKit
import WebPicCore

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    // Preview panel width — user-resizable via the splitter, remembered across launches.
    @AppStorage("wp.previewPanelWidth") private var panelWidth: Double = 300
    private let minPanel: Double = 240, maxPanel: Double = 440

    private let minMain: Double = 380   // keep the settings column usable at any panel width

    var body: some View {
        GeometryReader { geo in
            // Clamp the panel to the available width so a fixed-width panel can never be pushed
            // past the right window edge (which clipped its right padding at wide windows).
            let hasPanel = store.selected != nil
            let want = Swift.min(Swift.max(panelWidth, minPanel), maxPanel)
            let panelW = hasPanel ? Swift.max(200, Swift.min(want, geo.size.width - 8 - minMain)) : 0

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
                        // Force the content to the exact inner width. Relying on the ScrollView to
                        // propose its width let the image / progress-bar GeometryReader expand past
                        // the panel and get clipped (content looked glued to an edge).
                        PreviewColumn(image: img, store: store)
                            .frame(width: max(180, panelW - 40), alignment: .leading)
                            .padding(.horizontal, 20).padding(.vertical, 18)
                    }
                    .frame(width: panelW)
                    .frame(maxHeight: .infinity)
                    .background(p.window)
                    .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A draggable vertical splitter to resize the preview panel — the usual "drag the edge" affordance.
/// It's a full-width (8pt) strip so it's actually grabbable, with a hairline divider on its left edge.
private struct PanelSplitter: View {
    @Binding var width: Double
    let min: Double
    let max: Double
    @Environment(\.wpPalette) private var p
    @State private var dragStart: Double?
    @State private var hovering = false

    var body: some View {
        ZStack {
            p.window                                     // blends into the panel
            Rectangle().fill(hovering ? p.accent : p.sep)
                .frame(width: hovering ? 2 : 1)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 8)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil { dragStart = width }
                // Dragging left widens the panel, right narrows it.
                width = Swift.min(Swift.max((dragStart ?? width) - Double(v.translation.width), min), max)
            }
            .onEnded { _ in dragStart = nil })
    }
}
