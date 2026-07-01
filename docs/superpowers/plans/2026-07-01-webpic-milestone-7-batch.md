# WebPic Milestone 7 — Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The Batch screen — a grid of all images with live per-image status (Wartet / Verarbeitet + spinner / Fertig / Fehler), concurrent processing with **bounded parallelism**, the "Alle gleich behandeln" toggle, and "Alle entfernen".

**Architecture:** `WebPicImage` gains a `results: [EncodeResult]` field. `AppStore` gains `sameForAll` + an `@MainActor processAll()` that concurrently processes every URL-backed image through `ImageProcessor` with a concurrency cap (`min(cores, 4)`), updating each image's `status` (waiting → processing → done/error) and `results` on the main actor. `BatchView` renders the status-card grid and auto-runs `processAll` on entry. The single-image `processSelected` (M5) is unchanged; batch stores results per image.

**Tech Stack:** Swift 6, SwiftUI, Swift Concurrency (`withTaskGroup`, bounded).

**Reference:** BATCH block (`WebPic.dc.html` ~345–378). Spec §Batch. Builds on M1–M6. Addresses the M4/M5 review note to bound batch concurrency.

---

### Task 0: Batch engine — WebPicImage.results + AppStore.processAll

**Goal:** Per-image results storage and a concurrent, bounded `processAll()` that updates each image's status/results.

**Files:**
- Modify: `Sources/WebPicCore/Models/WebPicImage.swift` (add `results`)
- Modify: `Sources/WebPicCore/AppStore.swift` (add `sameForAll`, `processAll`, helpers)
- Test: `Tests/WebPicCoreTests/AppStoreBatchTests.swift`

**Acceptance Criteria:**
- [ ] `WebPicImage` has `results: [EncodeResult]` (default `[]`)
- [ ] `processAll()` sets every URL-backed image to `.done` with non-empty `results`; a non-image URL → `.error`
- [ ] never runs more than `min(cores, 4)` encodes concurrently (cap constant exposed for the test)
- [ ] `sameForAll` defaults to `true`

**Verify:** `swift test --filter AppStoreBatchTests`

**Steps:**

- [ ] **Step 1: Add `results` to `WebPicImage`** — after `thumbnailData`:
```swift
    /// Optimized outputs (populated by batch processing); empty until processed.
    public var results: [EncodeResult] = []
```
(Keep the existing initializer working — `results` has a default, so callers are unaffected. Do NOT add it as an init parameter unless needed.)

- [ ] **Step 2: Test** — `Tests/WebPicCoreTests/AppStoreBatchTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class AppStoreBatchTests: XCTestCase {
    private func fixtureURL(_ w: Int, _ h: Int) throws -> URL {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return url
    }

    func testProcessAllCompletesEveryImage() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        let urls = try (0..<3).map { _ in try fixtureURL(800, 500) }
        await store.importFiles(urls)
        store.settings.formats = [.webp, .jpeg]
        store.settings.compressionMode = .quality
        await store.processAll()
        XCTAssertEqual(store.images.count, 3)
        for img in store.images {
            XCTAssertEqual(img.status, .done)
            XCTAssertFalse(img.results.isEmpty)
        }
    }

    func testProcessAllMarksBadImageError() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        // A .png URL that isn't a real image
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString).png")
        try "not an image".data(using: .utf8)!.write(to: bad)
        // importFiles will reject the non-image (ImageImportService throws), so inject directly:
        store.images = [WebPicImage(id: "x", name: "bad.png", pixelWidth: 10, pixelHeight: 10,
                                    byteSize: 5, status: .waiting, url: bad)]
        await store.processAll()
        if case .error = store.images[0].status {} else { XCTFail("expected .error, got \(store.images[0].status)") }
    }

    func testConcurrencyCap() {
        XCTAssertLessThanOrEqual(AppStore.batchConcurrency, 4)
        XCTAssertGreaterThanOrEqual(AppStore.batchConcurrency, 1)
    }

    func testSameForAllDefault() {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        XCTAssertTrue(store.sameForAll)
    }
}
```

- [ ] **Step 3: Implement** — add to `AppStore`:
```swift
    public var sameForAll: Bool = true

    /// Max images encoded concurrently (bounded to protect memory — each large image ~48MB RGBA).
    public static let batchConcurrency = max(1, min(ProcessInfo.processInfo.activeProcessorCount - 2, 4))

    @MainActor private func setStatus(_ id: String, _ status: ImageStatus) {
        if let i = images.firstIndex(where: { $0.id == id }) { images[i].status = status }
    }
    @MainActor private func setResults(_ id: String, _ results: [EncodeResult]) {
        if let i = images.firstIndex(where: { $0.id == id }) { images[i].results = results }
    }

    /// Process every URL-backed image concurrently (bounded), updating status + results.
    @MainActor
    public func processAll() async {
        let settings = self.settings
        let ids: [String] = images.compactMap { $0.url != nil ? $0.id : nil }
        for id in ids { setStatus(id, .waiting); setResults(id, []) }

        await withTaskGroup(of: (String, [EncodeResult]?).self) { group in
            var iterator = ids.makeIterator()

            func urlFor(_ id: String) -> URL? { images.first { $0.id == id }?.url }

            func addNext() {
                guard let id = iterator.next() else { return }
                guard let url = urlFor(id) else { return }
                setStatus(id, .processing(0))
                group.addTask {
                    let out = await Task.detached(priority: .userInitiated) { () -> [EncodeResult]? in
                        let proc = ImageProcessor()
                        guard let cg = proc.loadCGImage(url: url) else { return nil }
                        if settings.compressionMode == .target {
                            return (try? proc.processForTarget(source: cg, settings: settings))?.results
                        } else {
                            return try? proc.process(source: cg, settings: settings)
                        }
                    }.value
                    return (id, out)
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
```

- [ ] **Step 4: Run — PASS**, commit
```bash
swift test --filter AppStoreBatchTests && swift build
git add Sources/WebPicCore/Models/WebPicImage.swift Sources/WebPicCore/AppStore.swift Tests/WebPicCoreTests/AppStoreBatchTests.swift
git commit -m "feat: batch engine — WebPicImage.results + bounded processAll (M7 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: Batch grid UI + wiring + screenshot

**Goal:** The `.batch` tab shows the "Alle gleich behandeln" toggle + "Alle entfernen" header and a grid of status cards; `processAll` runs on entry.

**Files:**
- Create: `Sources/WebPicApp/Batch/BatchView.swift`, `Sources/WebPicApp/Batch/BatchCard.swift`
- Modify: `Sources/WebPicApp/MainView.swift` (route `.batch` → `BatchView`)

**Acceptance Criteria:**
- [ ] header card: "Alle gleich behandeln" toggle (bound `store.sameForAll`) + note; divider; "Alle entfernen" button (calls `store.clearAll()`)
- [ ] grid (`LazyVGrid`, adaptive ~210pt) of cards: thumbnail, remove ×, per-status overlay (spinner while processing, error icon, done checkmark badge), name, `w×h · size`, status badge (colored dot + label)
- [ ] entering `.batch` runs `processAll`; cards update live to Fertig/Fehler
- [ ] `swift build` succeeds

**Verify:** `swift build` + screenshot (launch with `WEBPIC_IMPORT` + `WEBPIC_TAB=batch`).

**Steps:**

- [ ] **Step 1: BatchCard** — `Sources/WebPicApp/Batch/BatchCard.swift`
```swift
import SwiftUI
import WebPicCore

struct BatchCard: View {
    let image: WebPicImage
    let onRemove: () -> Void
    @Environment(\.wpPalette) private var p

    private var statusLabel: String {
        switch image.status {
        case .waiting: return "Wartet"
        case .processing: return "Verarbeitet …"
        case .done: return "Fertig"
        case .error: return "Fehler"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ThumbnailView(image: image, cornerRadius: 0).frame(height: 118).frame(maxWidth: .infinity).clipped()
                // status center overlay
                if case .processing = image.status {
                    ProgressView().controlSize(.small).tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if case .error = image.status {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 26)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // remove
                Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .frame(width: 24, height: 24).background(.black.opacity(0.42), in: Circle()).padding(9)
                // done badge
                if case .done = image.status {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(p.statusDone, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(9)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(image.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text("\(image.pixelWidth)×\(image.pixelHeight) · \(formatBytes(image.byteSize))")
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
                HStack(spacing: 5) {
                    Circle().fill(statusColor(image.status, p)).frame(width: 7, height: 7)
                    Text(statusLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(statusColor(image.status, p))
                }.padding(.top, 8)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
        }
        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.sep, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
```

- [ ] **Step 2: BatchView** — `Sources/WebPicApp/Batch/BatchView.swift`
```swift
import SwiftUI
import WebPicCore

struct BatchView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alle gleich behandeln").font(.system(size: 14, weight: .semibold))
                        Text(store.sameForAll ? "Ein Setting für alle Bilder" : "Jedes Bild einzeln einstellbar")
                            .font(.system(size: 12)).foregroundStyle(p.t3)
                    }
                    Toggle("", isOn: $store.sameForAll).labelsHidden().toggleStyle(.switch).tint(p.accent)
                    Rectangle().fill(p.sep).frame(width: 0.5, height: 26)
                    Button("Alle entfernen") { store.clearAll() }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).wpCard(p)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.images) { img in
                        BatchCard(image: img, onRemove: { store.remove(id: img.id) })
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(p.grouped)
        .task(id: batchKey) { await store.processAll() }
    }

    // Re-run when the set of images or the settings change.
    private var batchKey: String {
        store.images.map(\.id).joined(separator: ",") + "|" + store.settings.hashValueString
    }
}
```

- [ ] **Step 3: Route** — in `MainView.swift`, route `.batch` → `BatchView(store: store)` (remove the placeholder for `.batch`).

- [ ] **Step 4: Build + commit**
```bash
swift build && swift test
git add Sources/WebPicApp/Batch Sources/WebPicApp/MainView.swift
git commit -m "feat: Batch grid (status cards, same-for-all, remove-all) (M7 task 1)"
```
Controller then screenshots the batch grid (`WEBPIC_IMPORT` + `WEBPIC_TAB=batch`) showing Fertig/processing states.

---

## Milestone 7 acceptance
- [ ] `swift build` + `swift test` green
- [ ] Batch grid shows every image with correct live status; concurrent processing is bounded
- [ ] "Alle gleich behandeln" toggle + "Alle entfernen" work
- [ ] Screenshot verified

## Notes for later milestones
- **M8**: Sparkle auto-update (SPM), GitHub-Releases appcast, install flow + the update banner/modal (banner already in the sidebar); packaging (`.app`/DMG) + notarization decision.
- Per-image *individual* settings (when "Alle gleich behandeln" is off) is deferred — the toggle currently only changes the note; processing always uses the global settings.
- Carry forward: keepMetadata honoring; Photos-origin source data; downsampled Compare preview for very large images.
