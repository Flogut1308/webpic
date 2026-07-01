import SwiftUI
import WebPicCore

struct ExportView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var saveState: SaveState = .idle
    enum SaveState { case idle, busy, done }

    // Display order for the Format summary (do NOT use ImageProcessor.order — it's internal).
    private let formatOrder: [ImageFormat] = [.avif, .webp, .jpeg, .png]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                summaryCard
                if store.settings.compressionMode == CompressionMode.target, let q = store.chosenQuality {
                    autoQualityNote(q)
                }
                actions
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 28).padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(p.grouped)
        .task(id: "\(store.selectedID ?? "")-\(store.settings.hashValueString)") {
            await store.processSelected()
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            if let img = store.selected { ThumbnailView(image: img).frame(width: 112, height: 112) }
            VStack(alignment: .leading, spacing: 3) {
                Text("Bereit zum Export").font(.system(size: 22, weight: .bold))
                if let img = store.selected, let r = store.primaryResult {
                    let pct = img.byteSize > 0 ? max(0, Int((1 - Double(r.byteSize)/Double(img.byteSize))*100)) : 0
                    Text("\(formatBytes(r.byteSize)) · −\(pct)% kleiner · \(r.width)×\(r.height)")
                        .font(.system(size: 14)).foregroundStyle(p.t2)
                } else if store.processing {
                    Text("Optimiere …").font(.system(size: 14)).foregroundStyle(p.t2)
                }
            }
            Spacer()
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow("Ausgabe-Modus", outputLabel); Divider()
            summaryRow("Preset", presetLabel); Divider()
            summaryRow(
                "Format",
                store.settings.formats.isEmpty
                    ? "—"
                    : formatOrder.filter { store.settings.formats.contains($0) }.map(\.displayName).joined(separator: " · ")
            ); Divider()
            summaryRow(
                "Komprimierung",
                store.settings.compressionMode == CompressionMode.quality
                    ? "Qualität \(store.settings.quality)%"
                    : "Zieldateigröße \(store.settings.targetValue) \(store.settings.targetUnit == SizeUnit.kb ? "KB" : "MB")"
            )
            if store.settings.outputMode == OutputMode.responsive {
                Divider()
                summaryRow(
                    "Breakpoints",
                    store.settings.breakpoints.sorted().map { "\($0)w" }.joined(separator: " · ")
                )
            }
            Divider()
            summaryRow(
                "Farbraum & Metadaten",
                "\(store.settings.colorSpace == ColorSpace.sRGB ? "sRGB" : "Display P3") · \(store.settings.keepMetadata ? "Metadaten behalten" : "Metadaten entfernt")"
            ); Divider()
            summaryRow("Dateiname", store.settings.filenameScheme, mono: true)
        }
        .wpCard(p)
    }

    private func autoQualityNote(_ q: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(p.accent)
            (Text("Um die Zieldateigröße zu treffen, wurde die ")
             + Text("Qualität automatisch auf ≈\(q)%").fontWeight(.semibold)
             + Text(" angepasst. Auflösung und Format bleiben wie gewählt."))
                .font(.system(size: 13)).foregroundStyle(p.t1)
        }
        .padding(14).background(p.accentTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { save() } label: {
                HStack(spacing: 8) {
                    if saveState == .busy { ProgressView().controlSize(.small).tint(.white) }
                    else if saveState == .done { Image(systemName: "checkmark") }
                    Text(saveLabel)
                }.frame(height: 42).padding(.horizontal, 22)
            }
            .buttonStyle(.borderedProminent).tint(saveState == .done ? p.statusDone : p.accent)
            .disabled(saveState != .idle || store.results.isEmpty)

            Button { ExportActions.share(store.results) } label: {
                Label("Teilen", systemImage: "square.and.arrow.up").frame(height: 42).padding(.horizontal, 16)
            }.buttonStyle(.bordered).disabled(store.results.isEmpty)

            Button { store.sheet = .code } label: {
                Label("Code-Snippet", systemImage: "chevron.left.forwardslash.chevron.right").frame(height: 42).padding(.horizontal, 16)
            }.buttonStyle(.borderless).tint(p.accent)
        }
    }

    private var saveLabel: String {
        switch saveState {
        case .idle: return "In Fotos speichern"
        case .busy: return "Speichere …"
        case .done: return "Gespeichert"
        }
    }

    private func save() {
        guard let dir = ExportActions.pickDirectory() else { return }
        saveState = .busy
        let results = store.results
        let name = store.selected?.name ?? "image"
        let scheme = store.settings.filenameScheme
        Task {
            _ = try? ExportService.write(results: results, to: dir, originalName: name, scheme: scheme)
            saveState = .done
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            saveState = .idle
        }
    }

    private var outputLabel: String {
        switch store.settings.outputMode {
        case .single: return "Einzelbild"
        case .responsive: return "Responsive Set"
        case .convert: return "Nur Konvertierung"
        }
    }

    private var presetLabel: String {
        let pr = Preset.all.first { $0.key == store.settings.preset }!
        return "\(pr.label) · \(pr.sub)"
    }

    @ViewBuilder private func summaryRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(p.t2)
            Spacer()
            Text(value).font(mono ? .system(size: 12).monospacedDigit() : .system(size: 13, weight: .medium)).foregroundStyle(p.t1)
        }.padding(.horizontal, 18).padding(.vertical, 12)
    }
}
