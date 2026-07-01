# WebPic Milestone 5 — Compare + Export/Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Wire the real `ImageProcessor` into the UI — fix EXIF orientation, process the selected image on demand, show the before/after Compare screen and the Export/Review screen with real numbers and the chosen-quality note, and actually save files (folder / Photos / Share) using the filename scheme.

**Architecture:** `ImageProcessor.loadCGImage` becomes orientation-correct (CoreImage). A pure `FilenameFormatter` expands `{name}/{w}/{format}`. `AppStore` gains an `@MainActor processSelected()` that runs `ImageProcessor` off-main and caches `[EncodeResult]` + `chosenQuality`. New SwiftUI screens `CompareView` and `ExportView` replace the placeholder for the `.compare`/`.export` tabs and read the cached results. `ExportService` writes results to a directory (testable) behind `NSSavePanel`, saves to Photos, and shares via `NSSharingServicePicker`. A `WEBPIC_TAB` launch hook enables deterministic screenshots.

**Tech Stack:** Swift 6, SwiftUI, CoreImage (orientation), ImageIO, AppKit (`NSSavePanel`, `NSSharingServicePicker`), Photos.

**Reference:** COMPARE block (`WebPic.dc.html` ~379–404), EXPORT block (~405–448). Spec §6/§8. Builds on M1–M4.

**M4 review entry criteria addressed here:** EXIF orientation (Task 0). Concurrency memory bound is deferred to M7 (batch); M5 processes one image at a time.

---

### Task 0: Orientation-correct image loading

**Goal:** `ImageProcessor.loadCGImage(url:/data:)` applies the source's EXIF orientation so rotated photos are upright.

**Files:**
- Modify: `Sources/WebPicCore/Encoding/ImageResizer.swift` (add `applyOrientation`)
- Modify: `Sources/WebPicCore/Encoding/ImageProcessor.swift` (apply on load)
- Test: `Tests/WebPicCoreTests/OrientationTests.swift`

**Acceptance Criteria:**
- [ ] loading a 400×200 JPEG written with EXIF orientation 6 (90°) yields a **200×400** CGImage (dimensions swapped, upright)
- [ ] orientation 1 (or absent) returns the image unchanged
- [ ] full `swift test` green

**Verify:** `swift test --filter OrientationTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/OrientationTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class OrientationTests: XCTestCase {
    /// Write a 400×200 JPEG tagged with the given EXIF orientation.
    private func jpeg(orientation: UInt32) throws -> Data {
        let img = ImageIOEncoderTests.noisyImage(400, 200)
        let out = NSMutableData()
        let d = CGImageDestinationCreateWithData(out as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        _ = CGImageDestinationFinalize(d)
        return out as Data
    }

    func testOrientation6SwapsDimensions() throws {
        let data = try jpeg(orientation: 6)   // 90° → upright is 200×400
        let cg = ImageProcessor().loadCGImage(data: data)!
        XCTAssertEqual(cg.width, 200)
        XCTAssertEqual(cg.height, 400)
    }

    func testOrientation1Unchanged() throws {
        let data = try jpeg(orientation: 1)
        let cg = ImageProcessor().loadCGImage(data: data)!
        XCTAssertEqual(cg.width, 400)
        XCTAssertEqual(cg.height, 200)
    }
}
```

- [ ] **Step 2: applyOrientation** — add to `ImageResizer` (uses CoreImage for correctness):
```swift
import CoreImage
```
```swift
    /// Bake an EXIF orientation (1...8) into the pixels. Orientation 1 returns unchanged.
    public static func applyOrientation(_ image: CGImage, orientation: UInt32) -> CGImage {
        guard orientation != 1, let o = CGImagePropertyOrientation(rawValue: orientation) else { return image }
        let ci = CIImage(cgImage: image).oriented(o)
        let ctx = CIContext(options: nil)
        return ctx.createCGImage(ci, from: ci.extent) ?? image
    }
```

- [ ] **Step 3: Apply on load** — in `ImageProcessor`, route both loaders through orientation:
```swift
    public func loadCGImage(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return orientedImage(from: src)
    }
    public func loadCGImage(data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return orientedImage(from: src)
    }
    private func orientedImage(from src: CGImageSource) -> CGImage? {
        guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        return ImageResizer.applyOrientation(cg, orientation: orientation)
    }
```
(Replace the existing two `loadCGImage` methods.)

- [ ] **Step 4: Run — PASS**, commit
```bash
swift test --filter OrientationTests
git add Sources/WebPicCore/Encoding/ImageResizer.swift Sources/WebPicCore/Encoding/ImageProcessor.swift Tests/WebPicCoreTests/OrientationTests.swift
git commit -m "fix: apply EXIF orientation on image load (M5 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: FilenameFormatter

**Goal:** Expand the filename scheme `{name}`/`{w}`/`{format}` into an output filename.

**Files:**
- Create: `Sources/WebPicCore/Export/FilenameFormatter.swift`
- Test: `Tests/WebPicCoreTests/FilenameFormatterTests.swift`

**Acceptance Criteria:**
- [ ] `expand("{name}-{w}.{format}", name: "hero-banner", width: 1200, format: .webp)` → `"hero-banner-1200.webp"`
- [ ] the source extension in `name` is stripped (`"a.jpg"` → base `"a"`)
- [ ] AVIF/JPEG/PNG extensions map to `avif`/`jpg`/`png`; WebP → `webp`

**Verify:** `swift test --filter FilenameFormatterTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/FilenameFormatterTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class FilenameFormatterTests: XCTestCase {
    func testExpand() {
        XCTAssertEqual(
            FilenameFormatter.expand("{name}-{w}.{format}", name: "hero-banner", width: 1200, format: .webp),
            "hero-banner-1200.webp")
    }
    func testStripsSourceExtension() {
        XCTAssertEqual(
            FilenameFormatter.expand("{name}.{format}", name: "photo.jpeg", width: 800, format: .avif),
            "photo.avif")
    }
    func testExtensions() {
        XCTAssertEqual(FilenameFormatter.fileExtension(.jpeg), "jpg")
        XCTAssertEqual(FilenameFormatter.fileExtension(.png), "png")
        XCTAssertEqual(FilenameFormatter.fileExtension(.avif), "avif")
        XCTAssertEqual(FilenameFormatter.fileExtension(.webp), "webp")
    }
}
```

- [ ] **Step 2: Implement** — `Sources/WebPicCore/Export/FilenameFormatter.swift`
```swift
import Foundation

public enum FilenameFormatter {
    public static func fileExtension(_ format: ImageFormat) -> String {
        switch format {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .avif: return "avif"
        case .webp: return "webp"
        }
    }

    public static func expand(_ scheme: String, name: String, width: Int, format: ImageFormat) -> String {
        let base = (name as NSString).deletingPathExtension
        return scheme
            .replacingOccurrences(of: "{name}", with: base)
            .replacingOccurrences(of: "{w}", with: "\(width)")
            .replacingOccurrences(of: "{format}", with: fileExtension(format))
    }
}
```

- [ ] **Step 3: Run — PASS**, commit
```bash
swift test --filter FilenameFormatterTests
git add Sources/WebPicCore/Export Tests/WebPicCoreTests/FilenameFormatterTests.swift
git commit -m "feat: FilenameFormatter (scheme expansion) (M5 task 1)"
```

---

### Task 2: AppStore processing + ExportService.write

**Goal:** `AppStore.processSelected()` runs `ImageProcessor` off-main and caches `[EncodeResult]` + `chosenQuality`; `ExportService.write` writes results to a directory using the filename scheme (testable).

**Files:**
- Create: `Sources/WebPicCore/Export/ExportService.swift`
- Modify: `Sources/WebPicCore/AppStore.swift`
- Test: `Tests/WebPicCoreTests/ExportServiceTests.swift`, `Tests/WebPicCoreTests/AppStoreProcessTests.swift`

**Acceptance Criteria:**
- [ ] `ExportService.write(results:to:originalName:scheme:)` writes one file per result named by the scheme; returns the written URLs; files exist with the result bytes
- [ ] `AppStore.processSelected()` on a URL-backed image populates `results` (non-empty) and, in target mode, `chosenQuality`
- [ ] `processSelected()` sets `processing` true→false around the work

**Verify:** `swift test --filter ExportServiceTests` and `--filter AppStoreProcessTests`

**Steps:**

- [ ] **Step 1: ExportService** — `Sources/WebPicCore/Export/ExportService.swift`
```swift
import Foundation

public enum ExportService {
    @discardableResult
    public static func write(results: [EncodeResult], to directory: URL,
                             originalName: String, scheme: String) throws -> [URL] {
        var urls: [URL] = []
        for r in results {
            let filename = FilenameFormatter.expand(scheme, name: originalName, width: r.width, format: r.format)
            let url = directory.appendingPathComponent(filename)
            try r.data.write(to: url)
            urls.append(url)
        }
        return urls
    }
}
```

- [ ] **Step 2: Test ExportService** — `Tests/WebPicCoreTests/ExportServiceTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class ExportServiceTests: XCTestCase {
    func testWritesFilesWithScheme() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wp-exp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let results = [
            EncodeResult(format: .webp, width: 1200, height: 600, byteSize: 3, data: Data([1,2,3]), quality: 80),
            EncodeResult(format: .jpeg, width: 1200, height: 600, byteSize: 2, data: Data([4,5]), quality: 80),
        ]
        let urls = try ExportService.write(results: results, to: dir,
                                           originalName: "hero.png", scheme: "{name}-{w}.{format}")
        XCTAssertEqual(urls.map(\.lastPathComponent), ["hero-1200.webp", "hero-1200.jpg"])
        XCTAssertEqual(try Data(contentsOf: urls[0]), Data([1,2,3]))
    }
}
```

- [ ] **Step 3: AppStore processing** — add to `AppStore`:
```swift
    public private(set) var processing: Bool = false
    public private(set) var results: [EncodeResult] = []
    public private(set) var chosenQuality: Int? = nil

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
```

- [ ] **Step 4: Test AppStore processing** — `Tests/WebPicCoreTests/AppStoreProcessTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class AppStoreProcessTests: XCTestCase {
    private func fixtureURL(_ w: Int, _ h: Int) throws -> URL {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return url
    }

    func testProcessSelectedPopulatesResults() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        let url = try fixtureURL(1600, 1000)
        await store.importFiles([url])
        store.settings.formats = [.webp, .jpeg]
        store.settings.compressionMode = .quality
        await store.processSelected()
        XCTAssertFalse(store.processing)
        XCTAssertEqual(store.results.count, 2)
        XCTAssertNotNil(store.primaryResult)
    }
}
```

- [ ] **Step 5: Run — PASS**, commit
```bash
swift test --filter ExportServiceTests && swift test --filter AppStoreProcessTests && swift build
git add Sources/WebPicCore/Export/ExportService.swift Sources/WebPicCore/AppStore.swift Tests/WebPicCoreTests/ExportServiceTests.swift Tests/WebPicCoreTests/AppStoreProcessTests.swift
git commit -m "feat: AppStore.processSelected + ExportService.write (M5 task 2)"
```

---

### Task 3: Compare screen

**Goal:** The `.compare` tab shows a draggable before/after slider over Original/Optimiert plus three metric cards (−%, gespart, neue Auflösung), from real results. Processing runs on entering the tab.

**Files:**
- Create: `Sources/WebPicApp/Compare/CompareView.swift`
- Create: `Sources/WebPicApp/Compare/BeforeAfterSlider.swift`
- Modify: `Sources/WebPicApp/MainView.swift` (route `.compare` → `CompareView`; trigger `processSelected` on tab change)

**Acceptance Criteria:**
- [ ] `.compare` tab shows the original image left / optimized image right with a draggable vertical divider
- [ ] three metric cards: `−<savings>%`, gespart `<bytes>`, neue Auflösung `<w×h>` from real results (fallback to a spinner while `processing`)
- [ ] entering the Compare tab triggers `processSelected`
- [ ] `swift build` succeeds

**Verify:** `swift build` + screenshot

**Steps:**

- [ ] **Step 1: BeforeAfterSlider** — `Sources/WebPicApp/Compare/BeforeAfterSlider.swift`
```swift
import SwiftUI

struct BeforeAfterSlider: View {
    let before: NSImage
    let after: NSImage
    @State private var fraction: CGFloat = 0.5
    @Environment(\.wpPalette) private var p

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(nsImage: after).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                Image(nsImage: before).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geo.size.width * fraction)
                    }
                // labels
                Text("Original").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.black.opacity(0.5), in: Capsule()).foregroundStyle(.white).padding(14)
                Text("Optimiert").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(p.accent.opacity(0.85), in: Capsule()).foregroundStyle(.white).padding(14)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                // divider handle
                Rectangle().fill(.white).frame(width: 2).frame(maxHeight: .infinity)
                    .position(x: geo.size.width * fraction, y: geo.size.height / 2)
                    .shadow(radius: 1)
                Circle().fill(.white).frame(width: 36, height: 36).shadow(radius: 3)
                    .overlay { Image(systemName: "chevron.left.chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent) }
                    .position(x: geo.size.width * fraction, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                fraction = max(0, min(1, v.location.x / geo.size.width))
            })
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
```

- [ ] **Step 2: CompareView** — `Sources/WebPicApp/Compare/CompareView.swift`
```swift
import SwiftUI
import AppKit
import WebPicCore

struct CompareView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private var image: WebPicImage? { store.selected }
    private var result: EncodeResult? { store.primaryResult }

    private var beforeImage: NSImage? {
        guard let url = image?.url else { return image?.thumbnailData.flatMap(NSImage.init(data:)) }
        return NSImage(contentsOf: url)
    }
    private var afterImage: NSImage? { result.flatMap { NSImage(data: $0.data) } }

    var body: some View {
        VStack(spacing: 20) {
            if store.processing {
                ProgressView("Optimiere …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let img = image, let before = beforeImage, let after = afterImage, let r = result {
                BeforeAfterSlider(before: before, after: after)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 14) {
                    metric("Größenersparnis", "−\(savings(img, r))%", sub: "\(formatBytes(img.byteSize)) → \(formatBytes(r.byteSize))")
                    metric("Gespart", formatBytes(max(0, img.byteSize - r.byteSize)), sub: nil)
                    metric("Neue Auflösung", "\(r.width)×\(r.height)", sub: nil)
                }
            } else {
                Text("Keine Vorschau verfügbar").foregroundStyle(p.t3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.grouped)
        .task(id: taskKey) { await store.processSelected() }
    }

    private var taskKey: String { "\(store.selectedID ?? "")-\(store.settings.hashValueString)" }

    private func savings(_ img: WebPicImage, _ r: EncodeResult) -> Int {
        img.byteSize > 0 ? max(0, Int((1 - Double(r.byteSize)/Double(img.byteSize)) * 100)) : 0
    }

    @ViewBuilder private func metric(_ title: String, _ value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(p.t2)
            Text(value).font(.system(size: 28, weight: .semibold).monospacedDigit())
            if let sub { Text(sub).font(.system(size: 13).monospacedDigit()).foregroundStyle(p.t2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).wpCard(p)
    }
}
```
Add a stable settings key — in `Settings` (WebPicCore) add:
```swift
public extension Settings {
    /// Cheap identity string to retrigger processing when settings change.
    var hashValueString: String {
        "\(outputMode.rawValue)-\(preset.rawValue)-\(formats.map(\.rawValue).sorted().joined())-\(compressionMode.rawValue)-\(quality)-\(targetValue)-\(targetUnit.rawValue)-\(colorSpace.rawValue)"
    }
}
```

- [ ] **Step 3: Route + process trigger** — in `MainView`, route `.compare` to `CompareView(store: store)` (instead of the placeholder). Keep `.export`/`.batch` on placeholder for now.

- [ ] **Step 4: Build + commit**
```bash
swift build
git add Sources/WebPicApp/Compare Sources/WebPicApp/MainView.swift Sources/WebPicCore/Models/Settings.swift
git commit -m "feat: Compare screen (before/after slider + metrics) (M5 task 3)"
```

---

### Task 4: Export/Review screen

**Goal:** The `.export` tab shows a summary of all settings, the target-mode auto-quality note (real `chosenQuality`), and the action buttons (In Fotos speichern / Teilen / Code-Snippet) with Save button idle/busy/done states.

**Files:**
- Create: `Sources/WebPicApp/Export/ExportView.swift`
- Modify: `Sources/WebPicApp/MainView.swift` (route `.export` → `ExportView`)

**Acceptance Criteria:**
- [ ] shows summary rows: Ausgabe-Modus, Preset, Format, Komprimierung, (Breakpoints if responsive), Farbraum & Metadaten, Dateiname
- [ ] in target mode with results, shows "Qualität automatisch auf ≈<chosenQuality>% angepasst"
- [ ] three actions present; "In Fotos speichern" primary button reflects idle/busy/done
- [ ] entering the tab triggers `processSelected`; `swift build` succeeds

**Verify:** `swift build` + screenshot

**Steps:**

- [ ] **Step 1: ExportView** — `Sources/WebPicApp/Export/ExportView.swift`
```swift
import SwiftUI
import WebPicCore

struct ExportView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var saveState: SaveState = .idle
    enum SaveState { case idle, busy, done }

    private var s: Settings { store.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                summaryCard
                if s.compressionMode == .target, let q = store.chosenQuality {
                    autoQualityNote(q)
                }
                actions
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 28).padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.grouped)
        .task(id: "\(store.selectedID ?? "")-\(s.hashValueString)") { await store.processSelected() }
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
            summaryRow("Ausgabe-Modus", outputLabel)
            Divider()
            summaryRow("Preset", presetLabel)
            Divider()
            summaryRow("Format", s.formats.isEmpty ? "—" : ImageProcessor.order.filter { s.formats.contains($0) }.map(\.displayName).joined(separator: " · "))
            Divider()
            summaryRow("Komprimierung", s.compressionMode == .quality ? "Qualität \(s.quality)%" : "Zieldateigröße \(s.targetValue) \(s.targetUnit == .kb ? "KB" : "MB")")
            if s.outputMode == .responsive {
                Divider()
                summaryRow("Breakpoints", s.breakpoints.sorted().map { "\($0)w" }.joined(separator: " · "))
            }
            Divider()
            summaryRow("Farbraum & Metadaten", "\(s.colorSpace == .sRGB ? "sRGB" : "Display P3") · \(s.keepMetadata ? "Metadaten behalten" : "Metadaten entfernt")")
            Divider()
            summaryRow("Dateiname", s.filenameScheme, mono: true)
        }
        .wpCard(p)
    }

    private func autoQualityNote(_ q: Int) -> some View {
        HStack(spacing: 10) {
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
        switch saveState { case .idle: return "In Fotos speichern"; case .busy: return "Speichere …"; case .done: return "Gespeichert" }
    }

    private func save() {
        guard let dir = ExportActions.pickDirectory() else { return }
        saveState = .busy
        let results = store.results
        let name = store.selected?.name ?? "image"
        let scheme = s.filenameScheme
        Task {
            _ = try? ExportService.write(results: results, to: dir, originalName: name, scheme: scheme)
            saveState = .done
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            saveState = .idle
        }
    }

    private var outputLabel: String { ["single": "Einzelbild", "responsive": "Responsive Set", "convert": "Nur Konvertierung"][s.outputMode.rawValue] ?? "" }
    private var presetLabel: String { let pr = Preset.all.first { $0.key == s.preset }!; return "\(pr.label) · \(pr.sub)" }

    @ViewBuilder private func summaryRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(p.t2)
            Spacer()
            Text(value).font(mono ? .system(size: 12).monospacedDigit() : .system(size: 13, weight: .medium)).foregroundStyle(p.t1)
        }.padding(.horizontal, 18).padding(.vertical, 12)
    }
}
```

- [ ] **Step 2: ExportActions (AppKit)** — create `Sources/WebPicApp/Export/ExportActions.swift`
```swift
import AppKit
import WebPicCore

enum ExportActions {
    @MainActor static func pickDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Hier speichern"
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor static func share(_ results: [EncodeResult]) {
        guard let first = results.first else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(FilenameFormatter.expand("{name}-{w}.{format}", name: "image", width: first.width, format: first.format))
        try? first.data.write(to: tmp)
        let picker = NSSharingServicePicker(items: [tmp])
        if let win = NSApp.keyWindow, let view = win.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 3: Route** — in `MainView`, route `.export` → `ExportView(store: store)`.

- [ ] **Step 4: Build + commit**
```bash
swift build
git add Sources/WebPicApp/Export Sources/WebPicApp/MainView.swift
git commit -m "feat: Export/Review screen + save/share actions (M5 task 4)"
```

---

### Task 5: WEBPIC_TAB hook + screenshot verification

**Goal:** Add a `WEBPIC_TAB` launch hook (open on a given tab) for deterministic screenshots, and verify Compare + Export render with real results.

**Files:**
- Modify: `Sources/WebPicApp/WebPicMain.swift`

**Acceptance Criteria:**
- [ ] `WEBPIC_TAB=compare|export` opens on that tab
- [ ] screenshots show Compare (before/after + real metrics) and Export (summary + real optimized size)
- [ ] `swift build && swift test` green

**Verify:** build; controller launches with `WEBPIC_IMPORT` + `WEBPIC_TAB` and screenshots.

**Steps:**

- [ ] **Step 1: Hook** — in `WebPicMain.init`, after the import hook:
```swift
        switch env["WEBPIC_TAB"] {
        case "compare": store.tab = .compare
        case "export":  store.tab = .export
        case "batch":   store.tab = .batch
        default:        break
        }
```
(Place after the `WEBPIC_IMPORT` block so the imported image is selected first.)

- [ ] **Step 2: Build + verify + commit**
```bash
swift build && swift test
git add Sources/WebPicApp/WebPicMain.swift
git commit -m "feat: WEBPIC_TAB launch hook for screenshot verification (M5 task 5)"
```
Controller then screenshots Compare + Export (light + dark) with a real imported image.

---

## Milestone 5 acceptance
- [ ] `swift build` + `swift test` green
- [ ] EXIF orientation applied (rotated photos upright)
- [ ] Compare shows real before/after + real metrics; Export shows real summary + chosen-quality note
- [ ] Saving writes real optimized files (correct filename scheme); Share works
- [ ] Screenshot verified (Compare + Export, light + dark)

## Notes for later milestones
- **M6 Code-Snippets**: the code sheet (HTML/React/Next/Vue) + responsive `srcset` widths + `loading="lazy"`. `SnippetGenerator` is pure/testable.
- **M7 Batch**: concurrent processing with bounded parallelism (see M4 memory note); real per-image progress.
- Photos-origin images (url nil) currently can't be re-encoded at full res (only thumbnail) — retain original data or disable processing for them; revisit.
- "In Fotos speichern" currently writes to a chosen folder; true Photos-library save via the Photos framework can be added (needs the usage description already in the bundle).
- EXIF/ICC copy-through on export still pending (orientation is baked; other metadata is dropped).
