import SwiftUI
import WebPicCore

struct CompressionCard: View {
    @Bindable var store: AppStore
    let image: WebPicImage
    @Environment(\.wpPalette) private var p

    private var estBytes: Int { EstimationService.estimatedBytes(image: image, settings: store.settings) }
    private var savings: Int { EstimationService.savingsPercent(image: image, settings: store.settings) }
    private var hasError: Bool { EstimationService.targetError(image: image, settings: store.settings) }
    private var autoQ: Int { EstimationService.autoQuality(image: image, settings: store.settings) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Komprimierung").font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("", selection: $store.settings.compressionMode) {
                    Text("Qualität").tag(CompressionMode.quality)
                    Text("Zieldateigröße").tag(CompressionMode.target)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }
            .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 11)
            Divider()
            if store.settings.compressionMode == .quality {
                qualityBody
            } else {
                targetBody
            }
        }
        .wpCard(p)
    }

    private var qualityBody: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Qualität").font(.system(size: 13)).foregroundStyle(p.t2)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(store.settings.quality)").font(.system(size: 20, weight: .medium).monospacedDigit())
                    Text("%").font(.system(size: 13)).foregroundStyle(p.t3)
                }
            }.padding(.bottom, 6)
            Slider(value: Binding(
                get: { Double(store.settings.quality) },
                set: { store.settings.quality = Int($0.rounded()) }), in: 0...100)
            .tint(p.accent)
            HStack {
                Text("Geschätzte Ausgabe").font(.system(size: 12)).foregroundStyle(p.t2)
                Spacer()
                Text("\(formatBytes(estBytes)) · −\(savings)%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundStyle(p.t1)
            }.padding(.top, 12)
        }
        .padding(16)
    }

    private var targetBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Zieldateigröße").font(.system(size: 13)).foregroundStyle(p.t2).padding(.bottom, 9)
            HStack(spacing: 8) {
                TextField("", text: $store.settings.targetValue)
                    .textFieldStyle(.plain).font(.system(size: 15, weight: .medium).monospacedDigit())
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(p.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(hasError ? p.statusError : p.ctrlBorder, lineWidth: 1.5))
                Picker("", selection: $store.settings.targetUnit) {
                    Text("KB").tag(SizeUnit.kb)
                    Text("MB").tag(SizeUnit.mb)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 96)
            }
            if hasError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 12))
                    Text(errorMessage).font(.system(size: 12))
                }.foregroundStyle(p.statusError).padding(.top, 10)
            } else {
                (Text("Qualität wird automatisch auf ")
                 + Text("≈\(autoQ)%").font(.system(size: 12).monospacedDigit()).foregroundColor(p.t1)
                 + Text(" gesetzt, um dieses Ziel zu treffen."))
                    .font(.system(size: 12)).foregroundStyle(p.t2).padding(.top, 10)
            }
        }
        .padding(16)
    }

    private var errorMessage: String {
        let tb = EstimationService.targetBytes(store.settings)
        if tb.isNaN || tb <= 0 { return "Bitte eine gültige Zahl eingeben" }
        let mn = Int(EstimationService.feasibleMin(image: image, settings: store.settings))
        return "Zu klein – realistisch sind mind. \(formatBytes(mn))"
    }
}
