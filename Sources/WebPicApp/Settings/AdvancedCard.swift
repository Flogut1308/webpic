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
                    Toggle("", isOn: $store.activeSettings.keepMetadata).labelsHidden().toggleStyle(.switch).tint(p.accent)
                }
                Divider()
                row {
                    labelPair("Farbraum", "Für Web meist sRGB empfohlen")
                    Picker("", selection: $store.activeSettings.colorSpace) {
                        Text("sRGB").tag(ColorSpace.sRGB); Text("Display P3").tag(ColorSpace.displayP3)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                Divider()
                filenameSection
            }
        }
        .wpCard(p)
    }

    private var filenameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dateinamen-Schema").font(.system(size: 13, weight: .medium)).foregroundStyle(p.t1)
                Spacer()
                TextField("", text: $store.activeSettings.filenameScheme)
                    .textFieldStyle(.plain).font(.system(size: 12).monospacedDigit())
                    .frame(width: 220, height: 28).padding(.horizontal, 9)
                    .background(p.field, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
            }
            VStack(alignment: .leading, spacing: 3) {
                token("{name}", "Originalname ohne Endung")
                token("{w}", "Breite in Pixeln")
                token("{h}", "Höhe in Pixeln")
                token("{format}", "Dateiendung (webp, avif …)")
            }
            HStack(spacing: 6) {
                Text("Beispiel").font(.system(size: 12)).foregroundStyle(p.t3)
                Text(exampleFilename).font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundStyle(p.t1)
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.grouped, in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private func token(_ code: String, _ desc: String) -> some View {
        HStack(spacing: 8) {
            Text(code).font(.system(size: 11, weight: .medium).monospacedDigit()).foregroundStyle(p.accent)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(p.accentTint, in: RoundedRectangle(cornerRadius: 5))
            Text(desc).font(.system(size: 12)).foregroundStyle(p.t2)
        }
    }

    private var exampleFilename: String {
        let fmt = EstimationService.primaryFormat(store.activeSettings.formats)
        if let img = store.selected {
            let d = EstimationService.newDimensions(image: img, settings: store.activeSettings)
            return FilenameFormatter.expand(store.activeSettings.filenameScheme,
                                            name: img.name, width: d.width, height: d.height, format: fmt)
        }
        return FilenameFormatter.expand(store.activeSettings.filenameScheme,
                                        name: "bild.jpg", width: 1920, height: 1080, format: fmt)
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
