import SwiftUI
import WebPicCore

struct AdvancedCard: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.18)) { open.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(p.t2).rotationEffect(.degrees(open ? 90 : 0))
                    Text("Erweitert").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.t1)
                    Spacer()
                    Text("Metadaten, Farbraum, Dateiname").font(.system(size: 12)).foregroundStyle(p.t3)
                }
                .padding(.horizontal, 16).padding(.vertical, 13).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if open {
                Divider()
                row {
                    labelPair("Metadaten behalten", "EXIF, Copyright & Farbprofil")
                    Toggle("", isOn: $store.settings.keepMetadata).labelsHidden().toggleStyle(.switch).tint(p.accent)
                }
                Divider()
                row {
                    labelPair("Farbraum", "Für Web meist sRGB empfohlen")
                    Picker("", selection: $store.settings.colorSpace) {
                        Text("sRGB").tag(ColorSpace.sRGB); Text("Display P3").tag(ColorSpace.displayP3)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                Divider()
                row {
                    labelPair("Dateinamen-Schema", "Platzhalter: {name} {w} {format}")
                    TextField("", text: $store.settings.filenameScheme)
                        .textFieldStyle(.plain).font(.system(size: 12).monospacedDigit())
                        .frame(width: 200, height: 28).padding(.horizontal, 9)
                        .background(p.field, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
                }
            }
        }
        .wpCard(p)
    }

    @ViewBuilder private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 12) { content() }.padding(.horizontal, 16).padding(.vertical, 13)
    }
    @ViewBuilder private func labelPair(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(p.t1)
            Text(sub).font(.system(size: 12)).foregroundStyle(p.t3)
        }
        Spacer()
    }
}
