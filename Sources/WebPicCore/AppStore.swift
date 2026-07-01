import Foundation
import Observation

@Observable
public final class AppStore {
    public var images: [WebPicImage] = []
    public var selectedID: String?
    public var tab: Tab = .settings
    public var settings: Settings {
        didSet { persistSettings() }
    }
    public var sheet: SheetKind? = nil
    public var framework: SnippetFramework = .html
    public var lazyLoading: Bool = true
    public var showUpdate: Bool = true

    public private(set) var processing: Bool = false
    public private(set) var results: [EncodeResult] = []
    public private(set) var chosenQuality: Int? = nil

    public enum SheetKind: Sendable { case code, update }
    public enum SnippetFramework: String, CaseIterable, Sendable { case html, react, next, vue }

    @ObservationIgnored private let defaults: UserDefaults
    private static let settingsKey = "wp.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.settingsKey),
           let s = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = s
        } else {
            self.settings = .default
        }
    }

    public var isEmpty: Bool { images.isEmpty }
    public var selected: WebPicImage? {
        images.first { $0.id == selectedID } ?? images.first
    }

    /// Seed the reference mock images (used for screenshots / WEBPIC_SEED).
    public func seedMockImages() {
        images = MockData.seedImages()
        selectedID = images.first?.id
        tab = .settings
    }

    /// Import real image files. Decodes off-main, appends on main, dedupes by URL.
    @MainActor
    public func importFiles(_ urls: [URL]) async {
        for url in urls where !images.contains(where: { $0.url == url }) {
            let imported = await Task.detached(priority: .userInitiated) {
                try? ImageImportService.load(url: url)
            }.value
            guard let imported else { continue }
            images.append(WebPicImage(
                id: UUID().uuidString, name: imported.name,
                pixelWidth: imported.pixelWidth, pixelHeight: imported.pixelHeight,
                byteSize: imported.byteSize, status: .waiting,
                url: imported.url, thumbnailData: imported.thumbnailPNG))
        }
        if selectedID == nil { selectedID = images.first?.id }
        if tab != .batch { tab = .settings }
    }

    /// Import images from raw data (e.g. Photos). Appends on main.
    @MainActor
    public func importData(_ items: [(data: Data, name: String)]) async {
        for item in items {
            let imported = await Task.detached(priority: .userInitiated) {
                try? ImageImportService.load(data: item.data, name: item.name)
            }.value
            guard let imported else { continue }
            images.append(WebPicImage(
                id: UUID().uuidString, name: imported.name,
                pixelWidth: imported.pixelWidth, pixelHeight: imported.pixelHeight,
                byteSize: imported.byteSize, status: .waiting,
                url: nil, thumbnailData: imported.thumbnailPNG))
        }
        if selectedID == nil { selectedID = images.first?.id }
        if tab != .batch { tab = .settings }
    }

    public func select(id: String) {
        selectedID = id
        if tab == .batch { tab = .settings }
    }

    public func remove(id: String) {
        images.removeAll { $0.id == id }
        if selectedID == id { selectedID = images.first?.id }
    }

    public func clearAll() {
        images.removeAll()
        selectedID = nil
        tab = .settings
    }

    public func selectPreset(_ key: Preset.Key) {
        settings.preset = key
        settings.quality = Preset.defaultQuality(for: key)
    }

    public func toggleFormat(_ format: ImageFormat) {
        if settings.formats.contains(format) {
            settings.formats.remove(format)
        } else {
            settings.formats.insert(format)
        }
    }

    public func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }

    /// Run the real encoder on the selected (URL-backed) image; caches results.
    @MainActor
    public func processSelected() async {
        guard let img = selected, let url = img.url else { results = []; chosenQuality = nil; return }
        processing = true
        let settings = self.settings
        let output = await Task.detached(priority: .userInitiated) { () -> (results: [EncodeResult], chosen: Int?) in
            let proc = ImageProcessor()
            guard let cg = proc.loadCGImage(url: url) else { return ([], nil) }
            if settings.compressionMode == .target {
                if let t = try? proc.processForTarget(source: cg, settings: settings) {
                    return (t.results, t.chosenQuality)
                }
                return ([], nil)
            } else {
                let r = (try? proc.process(source: cg, settings: settings)) ?? []
                return (r, nil)
            }
        }.value
        self.results = output.results
        self.chosenQuality = output.chosen
        self.processing = false
    }

    /// The primary optimized result (for Compare/Export display), if computed.
    public var primaryResult: EncodeResult? {
        let primary = EstimationService.primaryFormat(settings.formats)
        return results.first { $0.format == primary } ?? results.first
    }
}
