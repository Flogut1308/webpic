import SwiftUI
import WebPicCore

struct BreakpointsCard: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var customText: String = ""

    private let defs: [(Int, String)] = [(400, "Mobil"), (800, "Tablet"), (1200, "Desktop"), (1920, "Retina / Hero")]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Breakpoints").font(.system(size: 14, weight: .semibold)); Spacer() }
                .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 11)
            Divider()
            ForEach(defs, id: \.0) { w, note in
                let on = store.activeSettings.breakpoints.contains(w)
                Button {
                    if on { store.activeSettings.breakpoints.remove(w) } else { store.activeSettings.breakpoints.insert(w) }
                } label: {
                    HStack(spacing: 11) {
                        checkbox(on)
                        Text("\(w)w").font(.system(size: 13, weight: .medium).monospacedDigit()).foregroundStyle(p.t1)
                        Spacer()
                        Text(note).font(.system(size: 12)).foregroundStyle(p.t3)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
            HStack(spacing: 10) {
                checkbox(false)   // decorative; custom width is honored by the encoder in M4
                Text("Eigene Breite").font(.system(size: 13)).foregroundStyle(p.t2)
                Spacer()
                TextField("z. B. 640", text: $customText)
                    .textFieldStyle(.plain).font(.system(size: 13).monospacedDigit())
                    .frame(width: 82, height: 28).padding(.horizontal, 9)
                    .background(p.field, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
                    .onChange(of: customText) { _, v in store.activeSettings.customBreakpoint = Int(v) }
                Text("w").font(.system(size: 12).monospacedDigit()).foregroundStyle(p.t3)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
        }
        .wpCard(p)
        .onAppear { if let c = store.activeSettings.customBreakpoint { customText = String(c) } }
    }

    @ViewBuilder private func checkbox(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(on ? p.accent : .clear)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(on ? p.accent : p.ctrlBorder, lineWidth: 1.5))
            .frame(width: 19, height: 19)
            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
    }
}
