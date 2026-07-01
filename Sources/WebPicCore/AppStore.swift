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
    public var showUpdate: Bool = false
    public var sameForAll: Bool = true
    public var availableUpdate: ReleaseInfo? = nil

    /// Max images encoded concurrently (bounded to protect memory — each large image ~48MB RGBA).
    public static let batchConcurrency = max(1, min(ProcessInfo.processInfo.activeProcessorCount - 2, 4))

    public private(set) var processing: Bool = false
    public private(set) var results: [EncodeResult] = []
    public private(set) var chosenQuality: Int? = nil

    public enum SheetKind: Sendable { case code, update }

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
        let targetID = img.id                 // guard against fast image switches
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
        // The selection may have changed while we were encoding — don't clobber the
        // current image's results with a stale run. The current selection's own task owns `processing`.
        guard selected?.id == targetID else { return }
        self.results = output.results
        self.chosenQuality = output.chosen
        self.processing = false
    }

    @MainActor private func setStatus(_ id: String, _ status: ImageStatus) {
        if let i = images.firstIndex(where: { $0.id == id }) { images[i].status = status }
    }
    @MainActor private func setResults(_ id: String, _ results: [EncodeResult]) {
        if let i = images.firstIndex(where: { $0.id == id }) { images[i].results = results }
    }

    /// Encode one URL-backed image off-main; returns nil on failure (bad/unreadable image).
    private func encode(url: URL, settings: Settings) async -> [EncodeResult]? {
        await Task.detached(priority: .userInitiated) { () -> [EncodeResult]? in
            let proc = ImageProcessor()
            guard let cg = proc.loadCGImage(url: url) else { return nil }
            if settings.compressionMode == .target {
                return (try? proc.processForTarget(source: cg, settings: settings))?.results
            } else {
                return try? proc.process(source: cg, settings: settings)
            }
        }.value
    }

    @ObservationIgnored private var batchSettingsHash = ""

    /// Process URL-backed images concurrently (bounded), updating status + results.
    /// On a settings change, re-encodes everything; on add/remove with unchanged settings,
    /// only processes images not already done (so completed cards don't flash back to "Wartet").
    @MainActor
    public func processAll() async {
        let settings = self.settings
        let hash = settings.hashValueString
        let full = hash != batchSettingsHash          // settings changed → reprocess all
        batchSettingsHash = hash
        let work: [(id: String, url: URL)] = images.compactMap { img in
            guard let url = img.url else { return nil }
            if !full, case .done = img.status, !img.results.isEmpty { return nil }  // keep done work
            return (img.id, url)
        }
        for (id, _) in work { setStatus(id, .waiting); setResults(id, []) }

        var iterator = work.makeIterator()

        await withTaskGroup(of: (String, [EncodeResult]?).self) { group in
            @MainActor func addNext() {
                guard let next = iterator.next() else { return }
                setStatus(next.id, .processing(0))
                group.addTask {
                    let out = await self.encode(url: next.url, settings: settings)
                    return (next.id, out)
                }
            }

            for _ in 0..<Self.batchConcurrency { addNext() }
            for await (id, out) in group {
                if let out, !out.isEmpty { setResults(id, out); setStatus(id, .done) }
                else { setStatus(id, .error("Verarbeitung fehlgeschlagen")) }
                addNext()
            }
        }
    }

    @MainActor
    public func checkForUpdate() async {
        let info = await UpdateChecker.fetchLatest(owner: "Flogut1308", repo: "webpic",
                                                   currentVersion: WebPicCore.version)
        availableUpdate = info
        showUpdate = (info != nil)
    }

    /// The primary optimized result (for Compare/Export display), if computed.
    public var primaryResult: EncodeResult? {
        let primary = EstimationService.primaryFormat(settings.formats)
        return results.first { $0.format == primary } ?? results.first
    }
}
