import SwiftUI
import AppKit
import WebPicCore

struct CodeSheet: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var copied = false

    private var code: String {
        guard let img = store.selected else { return "" }
        let w = store.primaryResult?.width ?? img.pixelWidth
        let h = store.primaryResult?.height ?? img.pixelHeight
        let base = (img.name as NSString).deletingPathExtension
        let formats: [ImageFormat] = [.avif, .webp, .jpeg, .png].filter { store.settings.formats.contains($0) }
        let input = SnippetInput(baseName: base, formats: formats, width: w, height: h,
                                 lazy: store.lazyLoading,
                                 responsive: store.settings.outputMode == .responsive,
                                 breakpoints: store.settings.breakpoints.sorted())
        return SnippetGenerator.code(framework: store.framework, input: input)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea().onTapGesture { store.sheet = nil }
            VStack(spacing: 0) {
                HStack {
                    Text("Code-Snippet").font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button { store.sheet = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).foregroundStyle(p.t2)
                        .frame(width: 26, height: 26).background(p.seg, in: RoundedRectangle(cornerRadius: 7))
                }.padding(.horizontal, 18).padding(.top, 15).padding(.bottom, 13)

                Picker("", selection: $store.framework) {
                    ForEach(SnippetFramework.allCases, id: \.self) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 18).padding(.bottom, 14)

                ZStack(alignment: .topTrailing) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HighlightedCode(code: code).padding(16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xF6F6F9), in: RoundedRectangle(cornerRadius: 11))
                    Button { copy() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12))
                            Text(copied ? "Kopiert" : "Kopieren").font(.system(size: 12, weight: .medium))
                        }.padding(.horizontal, 11).frame(height: 28)
                        .background(copied ? p.statusDone : p.ctrl, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(copied ? .white : p.t1)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
                    }.buttonStyle(.plain).padding(10)
                }.padding(.horizontal, 18)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("loading=\"lazy\" einschließen").font(.system(size: 13, weight: .medium))
                        Text("Verzögertes Laden für Bilder außerhalb des Viewports").font(.system(size: 12)).foregroundStyle(p.t3)
                    }
                    Spacer()
                    Toggle("", isOn: $store.lazyLoading).labelsHidden().toggleStyle(.switch).tint(p.accent)
                }.padding(.horizontal, 18).padding(.vertical, 15)
            }
            .frame(width: 620)
            .background(p.window, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 14)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        Task { try? await Task.sleep(nanoseconds: 1_600_000_000); copied = false }
    }
}
