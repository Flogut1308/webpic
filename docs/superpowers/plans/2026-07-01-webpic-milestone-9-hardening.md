# WebPic Milestone 9 — Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Close the highest-value known limitations from the M1–M8 reviews: (1) let Photos-imported images be re-encoded (retain source bytes) while unifying the duplicated encode-source loading, and (2) actually honor `keepMetadata` (preserve EXIF/ICC on export) for the ImageIO formats. Then bump to 2.1 and cut a release (which the running 2.0 app's updater will detect).

**Architecture:** `WebPicImage` gains `sourceData: Data?` (retained for data/Photos imports). A single `EncodeSource` enum + `ImageProcessor.loadCGImage(_: EncodeSource)` replaces the url-only loaders used in `processSelected`/`processAll`, so both paths resolve `url ?? sourceData`. `ImageIOEncoder.encode` gains an optional metadata dictionary; `ImageProcessor` threads the source's EXIF/ICC (orientation reset, since it's baked) into the destination when `settings.keepMetadata`.

**Scope / deferrals:** per-image batch settings (`sameForAll` "off") remains deferred — it's a distinct feature, not hardening. WebP metadata embedding (libwebp) is out of scope; `keepMetadata` applies to AVIF/JPEG/PNG (ImageIO) only, documented in-code.

**Tech Stack:** Swift 6, ImageIO/CoreGraphics, PhotosUI.

**Reference:** M5/M7 review carry-forwards. Builds on M1–M8.

---

### Task 0: Source-data retention + unified encode-source loading

**Goal:** Photos-imported (url-less) images can be optimized; `processSelected`/`processAll` share one source resolver.

**Files:**
- Modify: `Sources/WebPicCore/Models/WebPicImage.swift` (add `sourceData: Data?`)
- Modify: `Sources/WebPicCore/AppStore.swift` (`importData` stores bytes; `processSelected`/`processAll`/`encode` use unified source)
- Modify: `Sources/WebPicCore/Encoding/ImageProcessor.swift` (`EncodeSource` + `loadCGImage(_:)`)
- Test: `Tests/WebPicCoreTests/PhotosProcessTests.swift`

**Acceptance Criteria:**
- [ ] `WebPicImage.sourceData: Data?` (default nil); `importData` sets it to the imported bytes
- [ ] `ImageProcessor.loadCGImage(_ source: EncodeSource)` loads from `.url` or `.data`
- [ ] a data-imported (url == nil) image processes successfully via `processSelected` (non-empty results)
- [ ] existing url-import tests still pass

**Verify:** `swift test --filter PhotosProcessTests` + full suite

**Steps:**

- [ ] **Step 1: `sourceData`** — in `WebPicImage`, add after `thumbnailData`:
```swift
    /// Original image bytes for data/Photos imports (no `url` to re-read); nil for file imports.
    public var sourceData: Data?
```
Add it as a trailing initializer parameter with default nil:
```swift
    public init(..., thumbnailData: Data? = nil, sourceData: Data? = nil) {
        ...
        self.thumbnailData = thumbnailData
        self.sourceData = sourceData
    }
```
(Keep `results` as a non-init stored property as-is.)

- [ ] **Step 2: `EncodeSource` + loader** — in `ImageProcessor`:
```swift
    public enum EncodeSource: Sendable { case url(URL); case data(Data) }

    public func loadCGImage(_ source: EncodeSource) -> CGImage? {
        switch source {
        case .url(let u):  return loadCGImage(url: u)
        case .data(let d): return loadCGImage(data: d)
        }
    }
```
(Keep the existing `loadCGImage(url:)`/`(data:)` — they now back the enum.)

- [ ] **Step 3: importData stores bytes** — in `AppStore.importData`, set `sourceData: item.data` on the appended `WebPicImage`.

- [ ] **Step 4: unify source resolution** — add a helper and use it in both encode paths:
```swift
    /// Resolve the encode source for an image: file URL if present, else retained bytes.
    private func encodeSource(for image: WebPicImage) -> ImageProcessor.EncodeSource? {
        if let url = image.url { return .url(url) }
        if let data = image.sourceData { return .data(data) }
        return nil
    }
```
  - `processSelected`: replace the `guard let url = img.url` with `guard let source = encodeSource(for: img)`, and in the detached task use `proc.loadCGImage(source)`.
  - `processAll` / `encode(url:settings:)`: change to `encode(source:settings:)` taking `EncodeSource`; build the work list from `encodeSource(for:)` (include url-less images that have `sourceData`).

- [ ] **Step 5: Test** — `Tests/WebPicCoreTests/PhotosProcessTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class PhotosProcessTests: XCTestCase {
    private func pngData(_ w: Int, _ h: Int) -> Data {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let out = NSMutableData()
        let d = CGImageDestinationCreateWithData(out as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return out as Data
    }

    func testDataImportProcesses() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        await store.importData([(data: pngData(1200, 800), name: "photo-1.jpg")])
        XCTAssertEqual(store.images.count, 1)
        XCTAssertNil(store.images[0].url)                 // data import → no url
        XCTAssertNotNil(store.images[0].sourceData)
        store.settings.formats = [.webp, .jpeg]
        await store.processSelected()
        XCTAssertEqual(store.results.count, 2)            // now processable
    }
}
```

- [ ] **Step 6: Run — PASS**, commit
```bash
swift test && swift build
git add Sources/WebPicCore Tests/WebPicCoreTests/PhotosProcessTests.swift
git commit -m "feat: retain source bytes for Photos imports + unify encode-source loading (M9 task 0)"
```
(Body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: Honor keepMetadata (EXIF/ICC preservation, ImageIO formats)

**Goal:** When `settings.keepMetadata`, preserve the source's EXIF/ICC on AVIF/JPEG/PNG output (orientation reset to 1 since it's baked in).

**Files:**
- Modify: `Sources/WebPicCore/Encoding/ImageIOEncoder.swift` (accept optional metadata)
- Modify: `Sources/WebPicCore/Encoding/ImageEncoder.swift` (protocol: add metadata param with default)
- Modify: `Sources/WebPicCore/Encoding/ImageProcessor.swift` (read source metadata, pass when keepMetadata)
- Test: `Tests/WebPicCoreTests/MetadataTests.swift`

**Acceptance Criteria:**
- [ ] `ImageIOEncoder.encode(_:quality:metadata:)` writes the given metadata dictionary into the output; when nil, output has no injected EXIF
- [ ] a JPEG encoded with an EXIF dictionary (e.g. `{Exif:{UserComment:"webpic"}}`) round-trips that key when decoded
- [ ] `ImageProcessor` passes source EXIF/ICC only when `settings.keepMetadata` (orientation forced to 1); WebP path unaffected (documented)

**Verify:** `swift test --filter MetadataTests`

**Steps:**

- [ ] **Step 1: Protocol** — in `ImageEncoder.swift`, change the requirement to:
```swift
    func encode(_ image: CGImage, quality: Double, metadata: [CFString: Any]?) throws -> Data
```
Add a default-forwarding extension so existing call sites keep working:
```swift
public extension ImageEncoder {
    func encode(_ image: CGImage, quality: Double) throws -> Data {
        try encode(image, quality: quality, metadata: nil)
    }
}
```

- [ ] **Step 2: ImageIOEncoder** — update `encode` to accept `metadata: [CFString: Any]?` and, when non-nil, pass it as the properties to `CGImageDestinationAddImage` (merged with the lossy-quality entry). `WebPEncoder.encode` gains the `metadata:` parameter but ignores it (libwebp path) — add a `// WebP: metadata embedding not supported via libwebp` comment.

- [ ] **Step 3: ImageProcessor** — when `settings.keepMetadata`, read the source properties once (`CGImageSourceCopyPropertiesAtIndex`) in the loaders and thread them through; force `kCGImagePropertyOrientation = 1` (orientation is baked). Expose a way to get source metadata from `EncodeSource` (e.g. `sourceMetadata(_:) -> [CFString: Any]?`). Pass `metadata: settings.keepMetadata ? meta : nil` into each `encoder(for:).encode(...)` in `process`/`processForTarget`.

- [ ] **Step 4: Test** — `Tests/WebPicCoreTests/MetadataTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
@testable import WebPicCore

final class MetadataTests: XCTestCase {
    func testJPEGMetadataRoundTrips() throws {
        let img = ImageIOEncoderTests.noisyImage(64, 64)
        let meta: [CFString: Any] = [kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "webpic"]]
        let data = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.8, metadata: meta)
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertEqual(exif?[kCGImagePropertyExifUserComment] as? String, "webpic")
    }

    func testNoMetadataWhenNil() throws {
        let img = ImageIOEncoderTests.noisyImage(64, 64)
        let data = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.8, metadata: nil)
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        XCTAssertNil(props[kCGImagePropertyExifDictionary])
    }
}
```

- [ ] **Step 5: Run — PASS**, commit
```bash
swift test && swift build
git add Sources/WebPicCore/Encoding Tests/WebPicCoreTests/MetadataTests.swift
git commit -m "feat: honor keepMetadata — preserve EXIF/ICC on ImageIO encode (M9 task 1)"
```

---

### Task 2: Version bump 2.1 + v2.1 release

**Goal:** Bump the app version and cut a v2.1 release so the shipped 2.0 app detects an update.

**Files:**
- Modify: `Sources/WebPicCore/WebPicCore.swift` (`version = "2.1"`), `Tests/WebPicCoreTests/SmokeTests.swift` (expect "2.1"), `Scripts/bundle.sh` (Info.plist versions → 2.1)

**Acceptance Criteria:**
- [ ] `WebPicCore.version == "2.1"`; smoke test updated; bundle Info.plist `CFBundleShortVersionString`/`CFBundleVersion` = 2.1
- [ ] `swift test` green; `bundle.sh release` + `make-dmg.sh` produce `dist/WebPic.dmg`
- [ ] (controller) `gh release create v2.1 dist/WebPic.dmg` with notes

**Verify:** `swift test` + `bash Scripts/bundle.sh release && bash Scripts/make-dmg.sh`; controller cuts the release.

**Steps:**

- [ ] **Step 1:** set `WebPicCore.version = "2.1"`; update `SmokeTests` assertion to `"2.1"`; in `Scripts/bundle.sh` change the two `<string>2.0</string>` version values to `2.1`.
- [ ] **Step 2:** `swift test` + `swift build` green; commit:
```bash
git add Sources/WebPicCore/WebPicCore.swift Tests/WebPicCoreTests/SmokeTests.swift Scripts/bundle.sh
git commit -m "chore: bump version to 2.1 (M9 task 2)"
```
- [ ] **Step 3 (controller):** `bash Scripts/bundle.sh release && bash Scripts/make-dmg.sh`, then `gh release create v2.1 dist/WebPic.dmg --title "WebPic 2.1" --notes "<changelog>"`.

---

## Milestone 9 acceptance
- [ ] `swift build` + `swift test` green
- [ ] Photos-imported images can be optimized; encode-source loading unified
- [ ] `keepMetadata` preserves EXIF/ICC on AVIF/JPEG/PNG output (WebP documented as unsupported)
- [ ] Version bumped to 2.1; v2.1 release cut; the 2.0 app now shows a real update

## Notes
- Still deferred: per-image batch settings (`sameForAll` "off"); WebP EXIF embedding; downsampled Compare preview for very large images; update-check throttle.
