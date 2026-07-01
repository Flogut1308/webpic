import SwiftUI
import AppKit
import WebPicCore

struct UpdateSheet: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private var info: ReleaseInfo? { store.availableUpdate }
    private var sizeText: String {
        guard let b = info?.sizeBytes else { return "" }
        return " · Update ca. \(formatBytes(b))"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea().onTapGesture { store.sheet = nil }
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [p.accent, Color(hex: 0x5AC8FA)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .overlay { Image(systemName: "arrow.down.circle").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white) }
                        .padding(.bottom, 16)
                    Text("WebPic \(info?.version ?? "") ist verfügbar").font(.system(size: 18, weight: .bold))
                    Text("Du hast Version \(WebPicCore.version)\(sizeText)").font(.system(size: 13)).foregroundStyle(p.t2).padding(.top, 4)
                }.padding(.horizontal, 26).padding(.top, 26).padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 9) {
                    Text("NEU IN DIESER VERSION").font(.system(size: 11, weight: .semibold)).kerning(0.3).foregroundStyle(p.t3)
                    ForEach(Array((info?.notes ?? []).enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 9) {
                            Text("·").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent)
                            Text(note).font(.system(size: 13)).foregroundStyle(p.t1)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                .background(p.grouped, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20)

                HStack(spacing: 10) {
                    Button("Später") { store.dismissUpdate() }.buttonStyle(.bordered).controlSize(.large)
                    Button {
                        if let url = info?.downloadURL { NSWorkspace.shared.open(url) }
                        store.sheet = nil
                    } label: { Text("Installieren & neu starten").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(p.accent)
                }.padding(20)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11))
                    Text("Automatisch aktualisiert über GitHub-Releases").font(.system(size: 11))
                }.foregroundStyle(p.t3).padding(.bottom, 16)
            }
            .frame(width: 400)
            .background(p.window, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        }
    }
}
