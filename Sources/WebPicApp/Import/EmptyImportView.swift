import SwiftUI
import WebPicCore

struct EmptyImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.wpPalette) private var p

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(p.accentTint).frame(width: 72, height: 72)
                    .overlay { Image(systemName: "photo").font(.system(size: 30, weight: .light)).foregroundStyle(p.accent) }
                    .padding(.bottom, 22)
                Text("Bilder für das Web optimieren")
                    .font(.system(size: 22, weight: .bold))
                Text("Zieh Bilder aus Fotos oder dem Finder hierher – oder wähle sie manuell aus. WebP, AVIF & responsive Größen in Sekunden.")
                    .font(.system(size: 14)).foregroundStyle(p.t2)
                    .multilineTextAlignment(.center).lineSpacing(2)
                    .frame(maxWidth: 400).padding(.top, 8).padding(.bottom, 26)
                HStack(spacing: 10) {
                    Button("Bilder auswählen …") { store.addImages() }
                        .buttonStyle(.borderedProminent).tint(p.accent).controlSize(.large)
                    Button("Aus Fotos importieren") { store.addImages() }
                        .buttonStyle(.bordered).controlSize(.large)
                }
            }
            .padding(.vertical, 56).padding(.horizontal, 40)
            .frame(maxWidth: 560)
            .background(p.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(p.sep2, style: StrokeStyle(lineWidth: 2, dash: [6]))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
        .background(p.grouped)
    }
}
