# WebPic Milestone 2 — Import + Image Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the mock seed with real image import — Finder drag & drop, `NSOpenPanel` file picker, and Photos import — reading real dimensions/file size and generating real thumbnails, all funneling through one import pipeline.

**Architecture:** A pure `ImageImportService` (ImageIO) turns a file URL or raw `Data` into an `ImportedImage` (dimensions, byte size, thumbnail PNG). `AppStore` gains an `@MainActor importFiles/importData` pipeline that decodes off-main and appends on main. `WebPicImage` gains `thumbnailData`; a `ThumbnailView` prefers the real thumbnail and falls back to the gradient placeholder. Import entry points (open panel, drag-drop, PhotosPicker) all call the same pipeline. A `WEBPIC_IMPORT` launch hook enables deterministic screenshot verification of the real-thumbnail path.

**Tech Stack:** Swift 6, SwiftUI, ImageIO/CoreGraphics/UniformTypeIdentifiers, AppKit `NSOpenPanel`, PhotosUI.

**Reference:** [`docs/design-reference/WebPic.dc.html`](../../design-reference/WebPic.dc.html). Spec: [`docs/superpowers/specs/2026-07-01-webpic-design.md`](../specs/2026-07-01-webpic-design.md). Builds on Milestone 1.

**Carried from M1 review:** real thumbnails replace the 2-stop mock gradients (this milestone); the gradient stays only as a placeholder/fallback.

---

### Task 0: ImageImportService (ImageIO) — metadata + thumbnail

**Goal:** A pure, testable service that reads pixel dimensions + byte size and generates a thumbnail PNG from a file URL or raw image `Data`.

**Files:**
- Create: `Sources/WebPicCore/Import/ImageImportService.swift`
- Test: `Tests/WebPicCoreTests/ImageImportServiceTests.swift`

**Acceptance Criteria:**
- [ ] `load(url:)` on a 400×200 PNG returns pixelWidth 400, pixelHeight 200, byteSize > 0, non-nil `thumbnailPNG`
- [ ] the generated thumbnail's largest dimension ≤ the requested max pixel size
- [ ] `load(data:name:)` returns the same metadata from in-memory Data
- [ ] a non-image file throws `ImageImportError`

**Verify:** `swift test --filter ImageImportServiceTests`

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/ImageImportServiceTests.swift`

```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageImportServiceTests: XCTestCase {

    /// Write a solid-color PNG of the given size to a temp file, return its URL.
    private func makePNG(width: Int, height: Int) throws -> URL {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let img = ctx.makeImage()!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp-\(UUID().uuidString).png")
        let dest = CGImageDestinationCreateWithData(
            (try Data() as NSData).mutableCopy() as! CFMutableData, // placeholder, replaced below
            UTType.png.identifier as CFString, 1, nil)
        _ = dest // not used; write via destination-with-URL instead
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil)
        XCTAssertTrue(CGImageDestinationFinalize(d))
        return url
    }

    func testLoadURL() throws {
        let url = try makePNG(width: 400, height: 200)
        let imp = try ImageImportService.load(url: url, thumbnailMaxPixel: 160)
        XCTAssertEqual(imp.pixelWidth, 400)
        XCTAssertEqual(imp.pixelHeight, 200)
        XCTAssertGreaterThan(imp.byteSize, 0)
        XCTAssertNotNil(imp.thumbnailPNG)
        // Thumbnail max dimension <= 160
        let src = CGImageSourceCreateWithData(imp.thumbnailPNG! as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let tw = props[kCGImagePropertyPixelWidth] as! Int
        let th = props[kCGImagePropertyPixelHeight] as! Int
        XCTAssertLessThanOrEqual(max(tw, th), 160)
    }

    func testLoadData() throws {
        let url = try makePNG(width: 300, height: 300)
        let data = try Data(contentsOf: url)
        let imp = try ImageImportService.load(data: data, name: "sq.png", thumbnailMaxPixel: 160)
        XCTAssertEqual(imp.pixelWidth, 300)
        XCTAssertEqual(imp.pixelHeight, 300)
        XCTAssertEqual(imp.name, "sq.png")
    }

    func testNonImageThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp-\(UUID().uuidString).txt")
        try? "not an image".data(using: .utf8)!.write(to: url)
        XCTAssertThrowsError(try ImageImportService.load(url: url))
    }
}
```

> Note: the test helper's simplest correct form is to create the destination **with the URL** (`CGImageDestinationCreateWithURL`). If the implementer finds the placeholder `dest` line awkward, delete it — only the URL-based destination is needed.

- [ ] **Step 2: Run test — expect FAIL** (`ImageImportService` undefined)

Run: `swift test --filter ImageImportServiceTests` → FAIL

- [ ] **Step 3: Implement** — `Sources/WebPicCore/Import/ImageImportService.swift`

```swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct ImportedImage: Sendable {
    public let name: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let byteSize: Int
    public let thumbnailPNG: Data?
    public let url: URL?
}

public enum ImageImportError: Error, Sendable {
    case unreadable
    case notAnImage
}

public enum ImageImportService {
    /// Content types accepted by import entry points.
    public static let supportedTypes: [UTType] =
        [.jpeg, .png, .heic, .heif, .webP, .tiff, .gif]

    public static func load(url: URL, thumbnailMaxPixel: Int = 160) throws -> ImportedImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageImportError.unreadable
        }
        let byteSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return try build(from: src, name: url.lastPathComponent, url: url,
                         byteSize: byteSize, thumbnailMaxPixel: thumbnailMaxPixel)
    }

    public static func load(data: Data, name: String, thumbnailMaxPixel: Int = 160) throws -> ImportedImage {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageImportError.unreadable
        }
        return try build(from: src, name: name, url: nil,
                         byteSize: data.count, thumbnailMaxPixel: thumbnailMaxPixel)
    }

    private static func build(from src: CGImageSource, name: String, url: URL?,
                              byteSize: Int, thumbnailMaxPixel: Int) throws -> ImportedImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else {
            throw ImageImportError.notAnImage
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixel,
        ]
        var thumb: Data? = nil
        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
            thumb = pngData(from: cg)
        }
        return ImportedImage(name: name, pixelWidth: w, pixelHeight: h,
                             byteSize: byteSize, thumbnailPNG: thumb, url: url)
    }

    static func pngData(from image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
```

- [ ] **Step 4: Run test — expect PASS**, then commit

```bash
swift test --filter ImageImportServiceTests
git add Sources/WebPicCore/Import Tests/WebPicCoreTests/ImageImportServiceTests.swift
git commit -m "feat: ImageImportService (ImageIO metadata + thumbnail) (M2 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: WebPicImage thumbnail + ThumbnailView

**Goal:** Add real-thumbnail support to the model and a view that prefers the thumbnail, falling back to the gradient placeholder.

**Files:**
- Modify: `Sources/WebPicCore/Models/WebPicImage.swift`
- Create: `Sources/WebPicApp/Shared/ThumbnailView.swift`
- Modify: `Sources/WebPicApp/Sidebar/ImageRow.swift` (use `ThumbnailView`)
- Test: `Tests/WebPicCoreTests/WebPicImageTests.swift`

**Acceptance Criteria:**
- [ ] `WebPicImage` has `thumbnailData: Data?` (default nil); existing initializer calls still compile
- [ ] `ThumbnailView` renders an `Image` from `thumbnailData` when present, else a `GradientSwatch`
- [ ] `ImageRow` uses `ThumbnailView`
- [ ] `swift test` (full suite) stays green

**Verify:** `swift build && swift test`

**Steps:**

- [ ] **Step 1: Add field** — in `Sources/WebPicCore/Models/WebPicImage.swift`, add the stored property and initializer parameter (keep `gradient`):

Add property after `public var url: URL?`:
```swift
    /// PNG thumbnail bytes for real imports; nil → render the gradient placeholder.
    public var thumbnailData: Data?
```
Extend the initializer signature and body:
```swift
    public init(id: String, name: String, pixelWidth: Int, pixelHeight: Int,
                byteSize: Int, status: ImageStatus, url: URL? = nil,
                gradient: [UInt32] = [0x5AC8FA, 0x0A84FF], thumbnailData: Data? = nil) {
        self.id = id; self.name = name
        self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.byteSize = byteSize; self.status = status
        self.url = url; self.gradient = gradient
        self.thumbnailData = thumbnailData
    }
```

- [ ] **Step 2: Test** — `Tests/WebPicCoreTests/WebPicImageTests.swift`

```swift
import XCTest
@testable import WebPicCore

final class WebPicImageTests: XCTestCase {
    func testThumbnailDefaultsNil() {
        let img = WebPicImage(id: "x", name: "a.png", pixelWidth: 10, pixelHeight: 10,
                              byteSize: 100, status: .waiting)
        XCTAssertNil(img.thumbnailData)
    }
    func testThumbnailStored() {
        let d = Data([1, 2, 3])
        let img = WebPicImage(id: "x", name: "a.png", pixelWidth: 10, pixelHeight: 10,
                              byteSize: 100, status: .waiting, thumbnailData: d)
        XCTAssertEqual(img.thumbnailData, d)
    }
}
```

- [ ] **Step 3: ThumbnailView** — `Sources/WebPicApp/Shared/ThumbnailView.swift`

```swift
import SwiftUI
import AppKit
import WebPicCore

struct ThumbnailView: View {
    let image: WebPicImage
    var cornerRadius: CGFloat = 7

    var body: some View {
        Group {
            if let data = image.thumbnailData, let ns = NSImage(data: data) {
                Image(nsImage: ns)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                GradientSwatch(hexes: image.gradient, cornerRadius: cornerRadius)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
        }
    }
}
```

- [ ] **Step 4: Use it in `ImageRow`** — replace the `GradientSwatch(...).frame(width: 34, height: 34).overlay { ... }` block so the swatch becomes `ThumbnailView(image: image)`:

```swift
                ThumbnailView(image: image)
                    .frame(width: 34, height: 34)
                    .overlay {
                        if case .processing = image.status {
                            ProgressView().controlSize(.small).tint(.white)
                        } else if case .error = image.status {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.white).font(.system(size: 13, weight: .bold))
                        }
                    }
```

- [ ] **Step 5: Verify + commit**

```bash
swift test && swift build
git add Sources/WebPicCore/Models/WebPicImage.swift Sources/WebPicApp/Shared/ThumbnailView.swift Sources/WebPicApp/Sidebar/ImageRow.swift Tests/WebPicCoreTests/WebPicImageTests.swift
git commit -m "feat: real thumbnail support (WebPicImage.thumbnailData + ThumbnailView) (M2 task 1)"
```

---

### Task 2: AppStore import pipeline

**Goal:** `AppStore` imports real files/data through `ImageImportService` (decoding off-main, appending on main), dedupes by URL, selects the first, and keeps a mock-seed path for screenshots.

**Files:**
- Modify: `Sources/WebPicCore/AppStore.swift`
- Test: `Tests/WebPicCoreTests/AppStoreImportTests.swift`

**Acceptance Criteria:**
- [ ] `importFiles(_:)` appends a `WebPicImage` per readable URL, with `status == .waiting` and non-nil `thumbnailData`
- [ ] importing a URL already present is skipped (dedupe by `url`)
- [ ] after import into an empty store, `selectedID` is the first imported image
- [ ] `seedMockImages()` exists and reproduces the previous 4-image mock (used by `WEBPIC_SEED`)
- [ ] existing `AppStoreTests` still pass (rename any `addImages` mock usage there to `seedMockImages`)

**Verify:** `swift test --filter AppStore`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/AppStoreImportTests.swift`

```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class AppStoreImportTests: XCTestCase {
    private func makePNG(_ w: Int, _ h: Int) throws -> URL {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
        _ = CGImageDestinationFinalize(d)
        return url
    }
    private func store() -> AppStore { AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!) }

    func testImportAppendsAndSelects() async throws {
        let s = store()
        let u1 = try makePNG(400, 200)
        await s.importFiles([u1])
        XCTAssertEqual(s.images.count, 1)
        XCTAssertEqual(s.images[0].status, .waiting)
        XCTAssertNotNil(s.images[0].thumbnailData)
        XCTAssertEqual(s.selectedID, s.images.first?.id)
    }

    func testImportDedupesByURL() async throws {
        let s = store()
        let u1 = try makePNG(400, 200)
        await s.importFiles([u1])
        await s.importFiles([u1])
        XCTAssertEqual(s.images.count, 1)
    }

    func testSeedMockStillWorks() {
        let s = store()
        s.seedMockImages()
        XCTAssertEqual(s.images.count, 4)
    }
}
```

- [ ] **Step 2: Run — expect FAIL** (no `importFiles`/`seedMockImages`)

- [ ] **Step 3: Implement** — in `Sources/WebPicCore/AppStore.swift`:

Rename the existing `addImages()` mock body into `seedMockImages()`, and repoint `addImages()` semantics. Replace the current `addImages()` with:
```swift
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
        if tab == .batch { /* keep batch view */ } else { tab = .settings }
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
    }
```

- [ ] **Step 4: Repoint ALL `addImages()` callers** — renaming removes `addImages()`, so every caller must move to `seedMockImages()` in this task to keep the build green (Tasks 3/5 later rewire the UI buttons to the real pickers):
  - `Tests/WebPicCoreTests/AppStoreTests.swift`: `s.addImages()` → `s.seedMockImages()` (behavior identical; keep all other assertions). Note the M1 test `testSelectFromBatchGoesToSettings` seeds then sets `.batch` — still valid.
  - `Sources/WebPicApp/WebPicMain.swift`: the `WEBPIC_SEED` hook `store.addImages()` → `store.seedMockImages()`.
  - `Sources/WebPicApp/Sidebar/SidebarView.swift`: the "Bilder hinzufügen" button action `store.addImages()` → `store.seedMockImages()` (temporary — Task 3 rewires to `FilePicker`).
  - `Sources/WebPicApp/Import/EmptyImportView.swift`: both button actions `store.addImages()` → `store.seedMockImages()` (temporary — Tasks 3 & 5 rewire).
  - After this step, `grep -rn "addImages" Sources Tests` must return nothing.

- [ ] **Step 5: Run — expect PASS** (`swift test --filter AppStore` covers both files), then commit

```bash
swift test && swift build   # full suite + app target must stay green
git add Sources/WebPicCore/AppStore.swift Sources/WebPicApp/WebPicMain.swift Sources/WebPicApp/Sidebar/SidebarView.swift Sources/WebPicApp/Import/EmptyImportView.swift Tests/WebPicCoreTests/AppStoreImportTests.swift Tests/WebPicCoreTests/AppStoreTests.swift
git commit -m "feat: AppStore real import pipeline + seedMockImages (M2 task 2)"
```

---

### Task 3: File picker (NSOpenPanel) wiring

**Goal:** "Bilder auswählen …", the sidebar "Bilder hinzufügen", and (as the default) the empty-state buttons open a native multi-select image open-panel and import the chosen files.

**Files:**
- Create: `Sources/WebPicApp/Import/FilePicker.swift`
- Modify: `Sources/WebPicApp/Import/EmptyImportView.swift`
- Modify: `Sources/WebPicApp/Sidebar/SidebarView.swift`

**Acceptance Criteria:**
- [ ] `FilePicker.pickImages()` returns selected file URLs (multi-select, image types only)
- [ ] "Bilder auswählen …" and the sidebar "Bilder hinzufügen" open the panel and call `store.importFiles`
- [ ] `swift build` succeeds

**Verify:** `swift build` (interactive check via open-panel done manually / not screenshotted)

**Steps:**

- [ ] **Step 1: FilePicker** — `Sources/WebPicApp/Import/FilePicker.swift`

```swift
import AppKit
import WebPicCore

enum FilePicker {
    @MainActor
    static func pickImages() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ImageImportService.supportedTypes
        panel.prompt = "Importieren"
        panel.message = "Bilder zum Optimieren auswählen"
        return panel.runModal() == .OK ? panel.urls : []
    }
}
```

- [ ] **Step 2: Wire empty state** — in `EmptyImportView`, change the "Bilder auswählen …" button action from `store.addImages()` to:
```swift
                    Button("Bilder auswählen …") {
                        let urls = FilePicker.pickImages()
                        Task { await store.importFiles(urls) }
                    }
```
("Aus Fotos importieren" is wired in Task 5 — for now point it at the same `FilePicker.pickImages()` path so it isn't dead.)

- [ ] **Step 3: Wire sidebar** — in `SidebarView`, the "Bilder hinzufügen" button action becomes:
```swift
            Button {
                let urls = FilePicker.pickImages()
                Task { await store.importFiles(urls) }
            } label: { ... }   // keep existing label
```

- [ ] **Step 4: Build + commit**

```bash
swift build
git add Sources/WebPicApp/Import/FilePicker.swift Sources/WebPicApp/Import/EmptyImportView.swift Sources/WebPicApp/Sidebar/SidebarView.swift
git commit -m "feat: NSOpenPanel file import wiring (M2 task 3)"
```

---

### Task 4: Drag & drop from Finder

**Goal:** Dropping image files onto the empty/import area (and the populated detail area) imports them.

**Files:**
- Modify: `Sources/WebPicApp/MainView.swift`
- Modify: `Sources/WebPicApp/Import/EmptyImportView.swift`

**Acceptance Criteria:**
- [ ] The detail area accepts dropped file URLs and calls `store.importFiles`
- [ ] The empty-state drop-zone card shows a highlight while a drag is over it
- [ ] `swift build` succeeds

**Verify:** `swift build` (drag interaction verified manually)

**Steps:**

- [ ] **Step 1: Drop on detail** — in `MainView.body`, attach to the outer `Group`:
```swift
        .dropDestination(for: URL.self) { urls, _ in
            Task { await store.importFiles(urls) }
            return !urls.isEmpty
        }
```

- [ ] **Step 2: Highlight on empty zone** — in `EmptyImportView`, add drop state + border highlight:
```swift
    @State private var isTargeted = false
```
On the dashed card overlay, use the accent color while targeted:
```swift
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isTargeted ? p.accent : p.sep2,
                                  style: StrokeStyle(lineWidth: 2, dash: [6]))
            }
            .dropDestination(for: URL.self) { urls, _ in
                Task { await store.importFiles(urls) }
                return !urls.isEmpty
            } isTargeted: { isTargeted = $0 }
```

- [ ] **Step 3: Build + commit**

```bash
swift build
git add Sources/WebPicApp/MainView.swift Sources/WebPicApp/Import/EmptyImportView.swift
git commit -m "feat: Finder drag & drop import (M2 task 4)"
```

---

### Task 5: Photos import (PhotosUI)

**Goal:** "Aus Fotos importieren" presents a `PhotosPicker`; selected photos load as `Data` and import through `store.importData`.

**Files:**
- Create: `Sources/WebPicApp/Import/PhotosImportButton.swift`
- Modify: `Sources/WebPicApp/Import/EmptyImportView.swift` (use the button)
- Modify: `Scripts/bundle.sh` (add `NSPhotoLibraryUsageDescription`)

**Acceptance Criteria:**
- [ ] "Aus Fotos importieren" opens the system Photos picker (multi-select, images)
- [ ] Chosen photos load via `loadTransferable(type: Data.self)` and call `store.importData`
- [ ] `Info.plist` in the bundle contains `NSPhotoLibraryUsageDescription`
- [ ] `swift build && bash Scripts/bundle.sh` succeed

**Verify:** `swift build && bash Scripts/bundle.sh` (picker verified manually — needs a Photos library)

**Steps:**

- [ ] **Step 1: Photos button** — `Sources/WebPicApp/Import/PhotosImportButton.swift`

```swift
import SwiftUI
import PhotosUI
import WebPicCore

struct PhotosImportButton: View {
    @Environment(AppStore.self) private var store
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            Text("Aus Fotos importieren")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .onChange(of: selection) { _, items in
            let picked = items
            selection = []
            Task {
                var loaded: [(data: Data, name: String)] = []
                for (i, item) in picked.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append((data, "photo-\(i + 1).jpg"))
                    }
                }
                await store.importData(loaded)
            }
        }
    }
}
```

- [ ] **Step 2: Use it** — in `EmptyImportView`, replace the second button (`Button("Aus Fotos importieren") { ... }`) with `PhotosImportButton()`.

- [ ] **Step 3: Info.plist key** — in `Scripts/bundle.sh`, add inside the plist `<dict>`:
```
  <key>NSPhotoLibraryUsageDescription</key><string>WebPic importiert ausgewählte Fotos, um sie fürs Web zu optimieren.</string>
```

- [ ] **Step 4: Build + bundle + commit**

```bash
swift build && bash Scripts/bundle.sh
git add Sources/WebPicApp/Import/PhotosImportButton.swift Sources/WebPicApp/Import/EmptyImportView.swift Scripts/bundle.sh
git commit -m "feat: Photos import via PhotosPicker (M2 task 5)"
```

---

### Task 6: Launch import hook + verification

**Goal:** Add a `WEBPIC_IMPORT` launch hook (import given paths at startup) and verify the real import→thumbnail→display pipeline via a deterministic screenshot.

**Files:**
- Modify: `Sources/WebPicApp/WebPicMain.swift`

**Acceptance Criteria:**
- [ ] Launching with `WEBPIC_IMPORT=<path1>:<path2>` imports those image files at startup
- [ ] A screenshot with real imported images shows real thumbnails (not gradient placeholders) in the sidebar
- [ ] `swift build && swift test` green

**Verify:** build, generate fixture PNGs, launch with `WEBPIC_IMPORT`, screenshot, confirm real thumbnails.

**Steps:**

- [ ] **Step 1: Hook** — in `WebPicMain.init()`, after the seed/appearance hooks, add:
```swift
        if let paths = env["WEBPIC_IMPORT"], !paths.isEmpty {
            let urls = paths.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
            Task { await store.importFiles(urls) }
        }
```
(`store` is the local `let store` built in `init` before `_store = State(...)`.)

- [ ] **Step 2: Build, generate fixtures, screenshot** (controller runs this):
```bash
swift build && swift test
# controller generates 2 colorful PNGs to /tmp and captures:
#   WEBPIC_IMPORT=/tmp/a.png:/tmp/b.png dist/WebPic.app/Contents/MacOS/WebPic
# then screencapture the window and confirm real thumbnails render.
```

- [ ] **Step 3: Commit**

```bash
git add Sources/WebPicApp/WebPicMain.swift
git commit -m "feat: WEBPIC_IMPORT launch hook for screenshot verification (M2 task 6)"
```

---

## Milestone 2 acceptance

- [ ] `swift build` + `swift test` green (M1 tests still pass)
- [ ] Real files import via open-panel, drag & drop, and Photos, all through one pipeline
- [ ] Imported images show real thumbnails, correct dimensions and file size in the sidebar
- [ ] Dedupe by URL works; first import auto-selected; switches to settings
- [ ] Screenshot confirms real thumbnails render

## Notes for later milestones
- Imported images carry `status == .waiting` (not yet optimized). Real optimization + progress = M4/M7.
- `importFiles` loads sequentially (off-main per file). Concurrent batch processing with a `TaskGroup` and real progress = M7.
- Photos import writes no temp files (imports from Data); real EXIF/ICC handling = M4.
