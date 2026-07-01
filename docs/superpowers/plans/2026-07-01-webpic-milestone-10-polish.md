# WebPic Milestone 10 — Polish (v2.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Clear the remaining code-level limitations across three tiers — **small** (update-check throttle + skip-version, thumbnail-decode cache, honest install-button label), **medium** (WebP ICC embedding via WebPMux, downsampled Compare preview), **large** (per-image batch settings) — then release v2.2.

**Architecture:** Small items are localized (AppStore throttle state; a shared thumbnail cache; a label string). WebP ICC uses `WebPMux` (confirmed available) to attach an `ICCP` chunk from the color-converted image's ICC data, gated by the existing `keepMetadata` metadata signal. Per-image settings add `WebPicImage.settingsOverride: Settings?` and an `AppStore.activeSettings` get/set that routes to the selected image's override (when `sameForAll` is off) or the global settings; the settings UI and processing read through it.

**Tech Stack:** Swift 6, SwiftUI, libwebp/WebPMux, ImageIO/CoreGraphics.

**Scope note:** camera-EXIF/XMP embedding in WebP remains deferred (needs a raw-metadata channel); item 4 delivers the ICC/color-profile part. Signing/notarization + Sparkle stay out (need paid Apple account). Builds on M1–M9.

---

### Task 0 (small): Update-check throttle + skip-version

**Goal:** Don't re-check on every launch, and let dismissing an update suppress that version.

**Files:**
- Modify: `Sources/WebPicCore/AppStore.swift`
- Test: `Tests/WebPicCoreTests/UpdateThrottleTests.swift`

**Acceptance Criteria:**
- [ ] `checkForUpdate(now:)` takes an injectable `now: Date` (default `Date()`); skips the network call if `< 24h` since the last check (persisted in `UserDefaults`)
- [ ] `skipUpdate(_ version:)` records a skipped version (persisted); `checkForUpdate` does not set `showUpdate`/`availableUpdate` for a skipped version
- [ ] dismissing the update (a `dismissUpdate()` method) records the current `availableUpdate.version` as skipped and hides the banner

**Verify:** `swift test --filter UpdateThrottleTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/UpdateThrottleTests.swift`
```swift
import XCTest
@testable import WebPicCore

@MainActor
final class UpdateThrottleTests: XCTestCase {
    private func store() -> AppStore { AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!) }
    private func json(_ v: String) -> Data { #"{"tag_name":"\#(v)","html_url":"https://x/rel","body":"- n","assets":[]}"#.data(using: .utf8)! }

    func testThrottleSkipsWithin24h() async {
        let s = store()
        var calls = 0
        let loader: @Sendable (URL) async -> Data? = { _ in calls += 1; return self.json("2.9") }
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 1000), loader: loader)
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 1000 + 3600), loader: loader) // +1h
        XCTAssertEqual(calls, 1)      // second call throttled
        XCTAssertNotNil(s.availableUpdate)
    }

    func testSkippedVersionNotShown() async {
        let s = store()
        let loader: @Sendable (URL) async -> Data? = { _ in self.json("2.9") }
        s.skipUpdate("2.9")
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 5000), loader: loader)
        XCTAssertNil(s.availableUpdate)
        XCTAssertFalse(s.showUpdate)
    }

    func testDismissSkips() async {
        let s = store()
        let loader: @Sendable (URL) async -> Data? = { _ in self.json("2.9") }
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 9000), loader: loader)
        XCTAssertTrue(s.showUpdate)
        s.dismissUpdate()
        XCTAssertFalse(s.showUpdate)
        // a fresh check (past throttle) for the same version stays hidden
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 9000 + 90_000), loader: loader)
        XCTAssertNil(s.availableUpdate)
    }
}
```

- [ ] **Step 2: Implement** — in `AppStore`, replace the current `checkForUpdate()` with a throttled/injectable version and add skip state (persisted in the injected `defaults`):
```swift
    private static let lastCheckKey = "wp.update.lastCheck"
    private static let skipKey = "wp.update.skipVersion"

    public func skipUpdate(_ version: String) { defaults.set(version, forKey: Self.skipKey) }

    @MainActor
    public func dismissUpdate() {
        if let v = availableUpdate?.version { skipUpdate(v) }
        availableUpdate = nil
        showUpdate = false
        sheet = nil
    }

    @MainActor
    public func checkForUpdate(now: Date = Date(),
                               loader: @Sendable (URL) async -> Data? = { url in
                                   var req = URLRequest(url: url)
                                   req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                                   return try? await URLSession.shared.data(for: req).0
                               }) async {
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date
        if let last, now.timeIntervalSince(last) < 24 * 3600 { return }   // throttle
        defaults.set(now, forKey: Self.lastCheckKey)
        let info = await UpdateChecker.fetchLatest(owner: "Flogut1308", repo: "webpic",
                                                   currentVersion: WebPicCore.version, loader: loader)
        if let info, info.version == defaults.string(forKey: Self.skipKey) { return }  // skipped
        availableUpdate = info
        showUpdate = (info != nil)
    }
```
(`fetchLatest` already accepts a `loader`; pass it through.)

- [ ] **Step 3: Wire dismiss in the modal (app layer)** — in `UpdateSheet.swift`, change "Später" to call `store.dismissUpdate()` instead of just `store.sheet = nil`.

- [ ] **Step 4: Run — PASS**, commit
```bash
swift test --filter UpdateThrottleTests && swift build
git add Sources/WebPicCore/AppStore.swift Sources/WebPicApp/Update/UpdateSheet.swift Tests/WebPicCoreTests/UpdateThrottleTests.swift
git commit -m "feat: update-check throttle (24h) + skip-version on dismiss (M10 task 0)"
```
(Body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1 (small): Thumbnail decode cache + honest install label

**Goal:** Decode each thumbnail once (not per redraw); relabel the update install button.

**Files:**
- Create: `Sources/WebPicApp/Shared/ThumbnailCache.swift`
- Modify: `Sources/WebPicApp/Shared/ThumbnailView.swift`, `Sources/WebPicApp/Update/UpdateSheet.swift`

**Acceptance Criteria:**
- [ ] a process-wide `ThumbnailCache` (`NSCache<NSString, NSImage>`) keyed by image id returns a cached `NSImage`
- [ ] `ThumbnailView` uses the cache (decodes once per id) instead of `NSImage(data:)` every `body`
- [ ] the update modal's primary button reads "Update herunterladen" (honest — it opens the download)
- [ ] `swift build` succeeds

**Verify:** `swift build` (visual unchanged)

**Steps:**

- [ ] **Step 1: Cache** — `Sources/WebPicApp/Shared/ThumbnailCache.swift`
```swift
import AppKit

enum ThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(id: String, data: Data) -> NSImage? {
        if let hit = cache.object(forKey: id as NSString) { return hit }
        guard let img = NSImage(data: data) else { return nil }
        cache.setObject(img, forKey: id as NSString)
        return img
    }
}
```

- [ ] **Step 2: Use it** — in `ThumbnailView.body`, replace `NSImage(data: data)` with `ThumbnailCache.image(id: image.id, data: data)`.

- [ ] **Step 3: Label** — in `UpdateSheet.swift`, change the install button label `Text("Installieren & neu starten")` to `Text("Update herunterladen")`.

- [ ] **Step 4: Build + commit**
```bash
swift build
git add Sources/WebPicApp/Shared Sources/WebPicApp/Update/UpdateSheet.swift
git commit -m "perf: cache decoded thumbnails; honest update-download label (M10 task 1)"
```

---

### Task 2 (medium): WebP ICC-profile embedding (WebPMux)

**Goal:** When `keepMetadata` is on, embed the color-converted image's ICC profile into WebP output (matching what ImageIO does for the other formats).

**Files:**
- Modify: `Sources/WebPicCore/Encoding/WebPEncoder.swift`
- Test: `Tests/WebPicCoreTests/WebPICCTests.swift`

**Acceptance Criteria:**
- [ ] `WebPEncoder.encode(image, quality:, metadata:)` with `metadata != nil` and an ICC-bearing colorspace produces WebP bytes containing an `ICCP` RIFF chunk
- [ ] with `metadata == nil`, output has no `ICCP` chunk (unchanged behavior)
- [ ] output still decodes with correct dimensions

**Verify:** `swift test --filter WebPICCTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/WebPICCTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
@testable import WebPicCore

final class WebPICCTests: XCTestCase {
    /// A Display-P3 image so there's a non-trivial ICC profile to embed.
    private func p3Image(_ w: Int, _ h: Int) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.displayP3)!
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.3, alpha: 1)); ctx.fill(CGRect(x:0,y:0,width:w,height:h))
        return ctx.makeImage()!
    }
    private func hasChunk(_ data: Data, _ fourcc: String) -> Bool {
        data.range(of: fourcc.data(using: .ascii)!) != nil
    }

    func testICCEmbeddedWhenMetadata() throws {
        let img = p3Image(64, 64)
        let data = try WebPEncoder().encode(img, quality: 0.8, metadata: [:])   // non-nil → embed ICC
        XCTAssertTrue(hasChunk(data, "ICCP"), "expected ICCP chunk")
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 64)
    }

    func testNoICCWhenNil() throws {
        let img = p3Image(64, 64)
        let data = try WebPEncoder().encode(img, quality: 0.8, metadata: nil)
        XCTAssertFalse(hasChunk(data, "ICCP"))
    }
}
```

- [ ] **Step 2: Implement** — in `WebPEncoder.encode`, after producing the base WebP `Data` (call it `webp`), when `metadata != nil` and the image has ICC data, attach it via WebPMux:
```swift
        // existing WebPEncodeRGBA producing `let webp = Data(bytes: out, count: size)` ...
        guard metadata != nil,
              let cs = image.colorSpace,
              let icc = CGColorSpaceCopyICCData(cs) as Data? else { return webp }
        return Self.embedICC(webp, icc: icc) ?? webp
```
Add a helper using the Mux C API (all inside `WebPEncoder`):
```swift
    private static func embedICC(_ webp: Data, icc: Data) -> Data? {
        var input = WebPData(); var iccChunk = WebPData(); var assembled = WebPData()
        return webp.withUnsafeBytes { (wp: UnsafeRawBufferPointer) -> Data? in
            input.bytes = wp.bindMemory(to: UInt8.self).baseAddress
            input.size = webp.count
            guard let mux = WebPMuxCreate(&input, 1) else { return nil }
            defer { WebPMuxDelete(mux) }
            let ok: Data? = icc.withUnsafeBytes { (ib: UnsafeRawBufferPointer) -> Data? in
                iccChunk.bytes = ib.bindMemory(to: UInt8.self).baseAddress
                iccChunk.size = icc.count
                guard WebPMuxSetChunk(mux, "ICCP", &iccChunk, 1) == WEBP_MUX_OK else { return nil }
                guard WebPMuxAssemble(mux, &assembled) == WEBP_MUX_OK else { return nil }
                defer { WebPDataClear(&assembled) }
                return Data(bytes: assembled.bytes, count: assembled.size)
            }
            return ok
        }
    }
```
(`WebPData`, `WebPMuxCreate`, `WebPMuxSetChunk`, `WebPMuxAssemble`, `WebPMuxDelete`, `WebPDataClear`, `WEBP_MUX_OK` come from `import libwebp` (mux.h) — confirmed available.)

- [ ] **Step 3: Run — PASS**, commit
```bash
swift test --filter WebPICCTests && swift build
git add Sources/WebPicCore/Encoding/WebPEncoder.swift Tests/WebPicCoreTests/WebPICCTests.swift
git commit -m "feat: embed ICC profile in WebP via WebPMux when keepMetadata (M10 task 2)"
```

---

### Task 3 (medium): Downsampled Compare preview

**Goal:** The Compare "before" image shouldn't decode the full-resolution original on the main thread each redraw; use a downsampled thumbnail-scale image.

**Files:**
- Modify: `Sources/WebPicApp/Compare/CompareView.swift`

**Acceptance Criteria:**
- [ ] the "before" image is a downsampled decode (max ~1600px) via `CGImageSourceCreateThumbnailAtIndex`, cached, not a full-res `NSImage(contentsOf:)` on every `body`
- [ ] Compare still shows the correct before/after visuals and metrics
- [ ] `swift build` succeeds

**Verify:** `swift build` + screenshot

**Steps:**

- [ ] **Step 1:** add a helper (in `CompareView.swift` or a small shared file) that produces a downsampled `NSImage` from a URL or `Data` using ImageIO thumbnail options (`kCGImageSourceThumbnailMaxPixelSize: 1600`, `kCGImageSourceCreateThumbnailFromImageAlways: true`), and memoize it (e.g. keyed by image id via a small cache like `ThumbnailCache`, or `@State` recomputed on `selectedID` change). Replace `beforeImage`'s `NSImage(contentsOf: url)` with this downsampled load; keep the `after` image as-is (already small — the encoded result). Ensure the decode does not run on every `body` (compute in `.task`/cache, not a plain computed property).

- [ ] **Step 2: Build + commit**
```bash
swift build
git add Sources/WebPicApp/Compare
git commit -m "perf: downsampled Compare 'before' preview (no full-res main-thread decode) (M10 task 3)"
```

---

### Task 4 (large): Per-image batch settings

**Goal:** When "Alle gleich behandeln" is OFF, each image keeps its own settings; the Settings screen edits the selected image; processing honors per-image settings.

**Files:**
- Modify: `Sources/WebPicCore/Models/WebPicImage.swift` (add `settingsOverride: Settings?`)
- Modify: `Sources/WebPicCore/AppStore.swift` (`activeSettings` get/set; intents + processing route through effective settings)
- Modify: settings views to bind to `activeSettings`: `Sources/WebPicApp/Settings/SettingsView.swift`, `PresetCards.swift`, `FormatChips.swift`, `CompressionCard.swift`, `BreakpointsCard.swift`, `AdvancedCard.swift`, `PreviewColumn.swift`
- Test: `Tests/WebPicCoreTests/PerImageSettingsTests.swift`

**Acceptance Criteria:**
- [ ] `WebPicImage.settingsOverride: Settings?` (default nil)
- [ ] `AppStore.activeSettings` getter returns the selected image's override when `sameForAll == false` and an override exists, else global `settings`; setter writes to the selected image's override (creating it) when `sameForAll == false`, else to global
- [ ] `selectPreset`/`toggleFormat` operate on `activeSettings`
- [ ] `processSelected` uses the selected image's effective settings; `processAll` uses each image's effective settings (`settingsOverride ?? settings`)
- [ ] with `sameForAll == false`, changing the selected image's preset does NOT change another image's settings

**Verify:** `swift test --filter PerImageSettingsTests`

**Steps:**

- [ ] **Step 1: Model** — add to `WebPicImage`: `public var settingsOverride: Settings?` (default nil; NOT an init param — set post-init like `results`).

- [ ] **Step 2: AppStore effective settings** — add:
```swift
    /// Effective settings for a specific image (per-image override when present, else global).
    public func effectiveSettings(for image: WebPicImage) -> Settings {
        (!sameForAll ? image.settingsOverride : nil) ?? settings
    }

    /// The settings the UI edits: the selected image's override when per-image is on, else global.
    public var activeSettings: Settings {
        get {
            if !sameForAll, let sel = selected, let o = sel.settingsOverride { return o }
            return settings
        }
        set {
            if !sameForAll, let id = selectedID, let idx = images.firstIndex(where: { $0.id == id }) {
                images[idx].settingsOverride = newValue
            } else {
                settings = newValue
            }
        }
    }
```
   - Route `selectPreset`/`toggleFormat` through `activeSettings` (read-modify-write it) instead of `settings`.
   - `processSelected`: use `effectiveSettings(for: img)` instead of `self.settings`.
   - `processAll`: capture per-image effective settings — in the work list, pair each id with `effectiveSettings(for: img)` and pass that into `encode(source:settings:)` (change the work tuple to carry the settings, or look them up per task on the main actor before the detached call).

- [ ] **Step 3: Rebind settings UI** — in the settings views, change every `$store.settings.<x>` binding and `store.settings.<x>` read to `$store.activeSettings.<x>` / `store.activeSettings.<x>`:
  - `SettingsView` (Ausgabe picker), `PresetCards` (reads `store.settings.preset`), `FormatChips` (`store.settings.formats`), `CompressionCard` (all `store.settings.*`), `BreakpointsCard` (`store.settings.breakpoints`/`customBreakpoint`), `AdvancedCard` (`store.settings.keepMetadata`/`colorSpace`/`filenameScheme`), `PreviewColumn` (uses `store.settings` → `store.activeSettings`).
  - `selectPreset`/`toggleFormat` are already store methods (now routed via activeSettings), so `PresetCards`/`FormatChips` button actions are unchanged.
  - NOTE the `SwiftUI.Settings` name-collision rule still applies — never annotate the bare `Settings` type in a view.

- [ ] **Step 4: Test** — `Tests/WebPicCoreTests/PerImageSettingsTests.swift`
```swift
import XCTest
@testable import WebPicCore

@MainActor
final class PerImageSettingsTests: XCTestCase {
    private func store() -> AppStore {
        let s = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        s.images = [
            WebPicImage(id: "a", name: "a.jpg", pixelWidth: 100, pixelHeight: 100, byteSize: 1, status: .waiting),
            WebPicImage(id: "b", name: "b.jpg", pixelWidth: 100, pixelHeight: 100, byteSize: 1, status: .waiting),
        ]
        s.selectedID = "a"
        return s
    }

    func testActiveSettingsGlobalWhenSameForAll() {
        let s = store(); s.sameForAll = true
        s.selectPreset(.thumb)
        XCTAssertEqual(s.settings.preset, .thumb)           // edits global
        XCTAssertNil(s.images[0].settingsOverride)
    }

    func testPerImageOverrideIsolated() {
        let s = store(); s.sameForAll = false
        s.selectPreset(.icon)                                // edits image a's override
        XCTAssertEqual(s.images[0].settingsOverride?.preset, .icon)
        XCTAssertNil(s.images[1].settingsOverride)           // b untouched
        XCTAssertEqual(s.effectiveSettings(for: s.images[1]).preset, s.settings.preset)  // b uses global
        XCTAssertEqual(s.effectiveSettings(for: s.images[0]).preset, .icon)
    }
}
```

- [ ] **Step 5: Run — PASS**, build, commit
```bash
swift test --filter PerImageSettingsTests && swift build && swift test
git add Sources/WebPicCore Sources/WebPicApp/Settings Tests/WebPicCoreTests/PerImageSettingsTests.swift
git commit -m "feat: per-image batch settings (activeSettings + settingsOverride) (M10 task 4)"
```

---

### Task 5: Version bump 2.2 + release

**Goal:** Bump to 2.2 and cut the v2.2 release.

**Files:** `Sources/WebPicCore/WebPicCore.swift` (2.2), `Tests/WebPicCoreTests/SmokeTests.swift`, `Scripts/bundle.sh`, `Sources/WebPicApp/WebPicMain.swift` (the `WEBPIC_UPDATE` mock version if it hardcodes "2.1" → bump to "2.2" so the mock still reads as newer).

**Acceptance Criteria:**
- [ ] version 2.2 consistent (core, smoke test, bundle Info.plist); `swift test` green; DMG builds
- [ ] (controller) `gh release create v2.2 dist/WebPic.dmg`

**Verify:** `swift test && bash Scripts/bundle.sh release && bash Scripts/make-dmg.sh`; controller cuts release.

**Steps:** bump the four version references; `swift test` + build green; commit `chore: bump version to 2.2 (M10 task 5)`; controller builds DMG + `gh release create v2.2`.

---

## Milestone 10 acceptance
- [ ] `swift build` + `swift test` green
- [ ] Update check throttled (24h) + dismiss skips version; thumbnails cached; honest install label
- [ ] WebP carries an ICC profile when keepMetadata; Compare uses a downsampled preview
- [ ] Per-image batch settings work when "Alle gleich behandeln" is off
- [ ] Version 2.2 released

## Notes
- Still deferred: camera-EXIF/XMP embedding in WebP; signing/notarization + Sparkle (need paid Apple account).
