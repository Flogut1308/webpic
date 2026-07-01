# WebPic Milestone 4 — Real Encoder Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace mock estimates with a real image-processing engine — decode → resize → encode to WebP/AVIF/JPEG/PNG with correct dimensions and genuinely smaller files — plus a target-file-size binary search that records the chosen quality.

**Architecture:** An `ImageEncoder` protocol with two implementations: `ImageIOEncoder` (AVIF/JPEG/PNG via native `CGImageDestination`) and `WebPEncoder` (via the `libwebp` C library, already added). `ImageResizer` downscales (preserving aspect) and applies the target color space. `ImageProcessor` orchestrates decode→resize→encode over the selected formats, returning `[EncodeResult]`. `TargetSizeSolver` binary-searches quality to meet a byte budget. All pure/testable in `WebPicCore`; verified by tests that produce real, smaller, decodable files. No UI (real results are surfaced in M5 Compare/Export).

**Tech Stack:** Swift 6, CoreGraphics/ImageIO (AVIF/JPEG/PNG encode + decode), `libwebp` 1.5.0 (WebP encode), UniformTypeIdentifiers.

**Reference:** Spec §6 (ImageProcessor). Builds on M1–M3. `libwebp` (module `libwebp`) is already a dependency (commit adding `SDWebImage/libwebp-Xcode`).

**Empirically confirmed on this machine:** `CGImageDestination` encodes `public.avif`, `public.jpeg`, `public.png`, `public.heic` — but NOT WebP. So AVIF is native; only WebP uses `libwebp`.

**Scope note:** M4 delivers the engine + tests. Wiring real results into the Preview/Compare/Export UI (and retaining original bytes for Photos-origin images) is M5.

---

### Task 0: EncodeResult + ImageEncoder protocol + ImageIOEncoder (AVIF/JPEG/PNG)

**Goal:** The encode result model, the encoder protocol, and the native ImageIO encoder for AVIF/JPEG/PNG.

**Files:**
- Create: `Sources/WebPicCore/Encoding/EncodeResult.swift`
- Create: `Sources/WebPicCore/Encoding/ImageEncoder.swift`
- Create: `Sources/WebPicCore/Encoding/ImageIOEncoder.swift`
- Test: `Tests/WebPicCoreTests/ImageIOEncoderTests.swift`

**Acceptance Criteria:**
- [ ] `ImageIOEncoder(format: .jpeg/.png/.avif)` encodes a CGImage to non-empty `Data`
- [ ] each output decodes back via `CGImageSource` with the same pixel dimensions and the expected UTI
- [ ] JPEG at quality 0.3 is smaller than JPEG at quality 0.9 for a photographic fixture

**Verify:** `swift test --filter ImageIOEncoderTests`

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/ImageIOEncoderTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageIOEncoderTests: XCTestCase {
    /// A noisy RGB image so lossy quality actually changes size.
    static func noisyImage(_ w: Int, _ h: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1; return CGFloat((seed >> 33) & 0xff) / 255 }
        for y in stride(from: 0, to: h, by: 4) {
            for x in stride(from: 0, to: w, by: 4) {
                ctx.setFillColor(red: rnd(), green: rnd(), blue: rnd(), alpha: 1)
                ctx.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        return ctx.makeImage()!
    }

    func decodeDims(_ data: Data) -> (Int, Int, String)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(src) as String?,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h, uti)
    }

    func testEncodesEachFormat() throws {
        let img = Self.noisyImage(320, 200)
        for fmt in [ImageFormat.jpeg, .png, .avif] {
            let data = try ImageIOEncoder(format: fmt).encode(img, quality: 0.7)
            XCTAssertFalse(data.isEmpty, "\(fmt) empty")
            let dims = decodeDims(data)
            XCTAssertNotNil(dims, "\(fmt) not decodable")
            XCTAssertEqual(dims?.0, 320); XCTAssertEqual(dims?.1, 200)
        }
    }

    func testJpegQualityAffectsSize() throws {
        let img = Self.noisyImage(400, 300)
        let lo = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.3)
        let hi = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.9)
        XCTAssertLessThan(lo.count, hi.count)
    }
}
```

- [ ] **Step 2: EncodeResult** — `Sources/WebPicCore/Encoding/EncodeResult.swift`
```swift
import Foundation

public struct EncodeResult: Sendable, Equatable {
    public let format: ImageFormat
    public let width: Int
    public let height: Int
    public let byteSize: Int
    public let data: Data
    public let quality: Int          // 0...100 (100 for lossless PNG)

    public init(format: ImageFormat, width: Int, height: Int, byteSize: Int, data: Data, quality: Int) {
        self.format = format; self.width = width; self.height = height
        self.byteSize = byteSize; self.data = data; self.quality = quality
    }
}
```

- [ ] **Step 3: ImageEncoder protocol** — `Sources/WebPicCore/Encoding/ImageEncoder.swift`
```swift
import CoreGraphics
import Foundation

public enum EncodeError: Error, Sendable { case destinationFailed, finalizeFailed, encodeFailed }

public protocol ImageEncoder: Sendable {
    var format: ImageFormat { get }
    /// Encode a CGImage. `quality` is 0.0...1.0 (ignored by lossless PNG).
    func encode(_ image: CGImage, quality: Double) throws -> Data
}
```

- [ ] **Step 4: ImageIOEncoder** — `Sources/WebPicCore/Encoding/ImageIOEncoder.swift`
```swift
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

public struct ImageIOEncoder: ImageEncoder {
    public let format: ImageFormat
    public init(format: ImageFormat) { self.format = format }

    private var uti: CFString {
        switch format {
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .png:  return UTType.png.identifier as CFString
        case .avif: return "public.avif" as CFString
        case .webp: return "org.webmproject.webp" as CFString  // not used; WebPEncoder handles WebP
        }
    }

    public func encode(_ image: CGImage, quality: Double) throws -> Data {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, uti, 1, nil) else {
            throw EncodeError.destinationFailed
        }
        var props: [CFString: Any] = [:]
        if format != .png {
            props[kCGImageDestinationLossyCompressionQuality] = max(0, min(1, quality))
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw EncodeError.finalizeFailed }
        return out as Data
    }
}
```

- [ ] **Step 5: Run — PASS**, commit
```bash
swift test --filter ImageIOEncoderTests
git add Sources/WebPicCore/Encoding Tests/WebPicCoreTests/ImageIOEncoderTests.swift
git commit -m "feat: ImageEncoder protocol + ImageIOEncoder (AVIF/JPEG/PNG) (M4 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: WebPEncoder (libwebp)

**Goal:** Encode a CGImage to WebP via `libwebp`.

**Files:**
- Create: `Sources/WebPicCore/Encoding/WebPEncoder.swift`
- Test: `Tests/WebPicCoreTests/WebPEncoderTests.swift`

**Acceptance Criteria:**
- [ ] `WebPEncoder().encode(image, quality:)` returns non-empty Data starting with `RIFF`…`WEBP`
- [ ] the output decodes via `CGImageSource` (ImageIO decodes WebP) with the same dimensions
- [ ] quality 0.2 is smaller than quality 0.9 for a noisy fixture

**Verify:** `swift test --filter WebPEncoderTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/WebPEncoderTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
@testable import WebPicCore

final class WebPEncoderTests: XCTestCase {
    func testWebPHeaderAndDecode() throws {
        let img = ImageIOEncoderTests.noisyImage(320, 200)
        let data = try WebPEncoder().encode(img, quality: 0.75)
        XCTAssertGreaterThan(data.count, 12)
        let bytes = [UInt8](data.prefix(12))
        XCTAssertEqual(Array(bytes[0..<4]), Array("RIFF".utf8))
        XCTAssertEqual(Array(bytes[8..<12]), Array("WEBP".utf8))
        // ImageIO can decode WebP → verify dimensions
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 320)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 200)
    }

    func testWebPQualityAffectsSize() throws {
        let img = ImageIOEncoderTests.noisyImage(400, 300)
        let lo = try WebPEncoder().encode(img, quality: 0.2)
        let hi = try WebPEncoder().encode(img, quality: 0.9)
        XCTAssertLessThan(lo.count, hi.count)
    }
}
```

- [ ] **Step 2: Implement** — `Sources/WebPicCore/Encoding/WebPEncoder.swift`
```swift
import CoreGraphics
import Foundation
import libwebp

public struct WebPEncoder: ImageEncoder {
    public let format: ImageFormat = .webp
    public init() {}

    public func encode(_ image: CGImage, quality: Double) throws -> Data {
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * height)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw EncodeError.encodeFailed
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var output: UnsafeMutablePointer<UInt8>? = nil
        let q = Float(max(0, min(1, quality)) * 100)
        let size = rgba.withUnsafeBufferPointer { buf in
            WebPEncodeRGBA(buf.baseAddress, Int32(width), Int32(height), Int32(bytesPerRow), q, &output)
        }
        guard size > 0, let out = output else { throw EncodeError.encodeFailed }
        defer { WebPFree(out) }
        return Data(bytes: out, count: size)
    }
}
```

- [ ] **Step 3: Run — PASS**, commit
```bash
swift test --filter WebPEncoderTests
git add Sources/WebPicCore/Encoding/WebPEncoder.swift Tests/WebPicCoreTests/WebPEncoderTests.swift
git commit -m "feat: WebPEncoder via libwebp (M4 task 1)"
```

---

### Task 2: ImageResizer (downscale + color space)

**Goal:** Downscale a CGImage to a target width (preserving aspect, high quality) and convert to the requested color space.

**Files:**
- Create: `Sources/WebPicCore/Encoding/ImageResizer.swift`
- Test: `Tests/WebPicCoreTests/ImageResizerTests.swift`

**Acceptance Criteria:**
- [ ] `resize(image, toWidth: 200)` on a 400×200 image returns a 200×100 CGImage
- [ ] `resize(..., toWidth:)` never upscales (width ≥ source width returns source unchanged size)
- [ ] `convert(image, to: .displayP3)` returns a CGImage whose color space name contains "P3"; `.sRGB` contains "sRGB"

**Verify:** `swift test --filter ImageResizerTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/ImageResizerTests.swift`
```swift
import XCTest
import CoreGraphics
@testable import WebPicCore

final class ImageResizerTests: XCTestCase {
    func testDownscalePreservesAspect() {
        let img = ImageIOEncoderTests.noisyImage(400, 200)
        let out = ImageResizer.resize(img, toWidth: 200)
        XCTAssertEqual(out.width, 200)
        XCTAssertEqual(out.height, 100)
    }
    func testNoUpscale() {
        let img = ImageIOEncoderTests.noisyImage(300, 300)
        let out = ImageResizer.resize(img, toWidth: 600)
        XCTAssertEqual(out.width, 300)
        XCTAssertEqual(out.height, 300)
    }
    func testColorSpaceConversion() {
        let img = ImageIOEncoderTests.noisyImage(50, 50)
        let p3 = ImageResizer.convert(img, to: .displayP3)
        XCTAssertTrue((p3.colorSpace?.name as String? ?? "").contains("P3"))
        let srgb = ImageResizer.convert(img, to: .sRGB)
        XCTAssertTrue((srgb.colorSpace?.name as String? ?? "").localizedCaseInsensitiveContains("srgb"))
    }
}
```

- [ ] **Step 2: Implement** — `Sources/WebPicCore/Encoding/ImageResizer.swift`
```swift
import CoreGraphics
import Foundation

public enum ImageResizer {
    /// Downscale to `toWidth` preserving aspect ratio. Never upscales.
    public static func resize(_ image: CGImage, toWidth: Int) -> CGImage {
        let w = image.width, h = image.height
        guard toWidth > 0, toWidth < w else { return image }
        let newW = toWidth
        let newH = max(1, Int((Double(h) * Double(newW) / Double(w)).rounded()))
        let cs = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: newW, height: newH, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? image
    }

    public static func convert(_ image: CGImage, to colorSpace: ColorSpace) -> CGImage {
        let cs: CGColorSpace = colorSpace == .displayP3
            ? (CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB())
            : (CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB())
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}
```

- [ ] **Step 3: Run — PASS**, commit
```bash
swift test --filter ImageResizerTests
git add Sources/WebPicCore/Encoding/ImageResizer.swift Tests/WebPicCoreTests/ImageResizerTests.swift
git commit -m "feat: ImageResizer (downscale + color space) (M4 task 2)"
```

---

### Task 3: ImageProcessor (decode → resize → encode)

**Goal:** Orchestrate: load a source CGImage (URL or Data) → resize to the settings' target width → convert color space → encode every selected format at the given quality → `[EncodeResult]`.

**Files:**
- Create: `Sources/WebPicCore/Encoding/ImageProcessor.swift`
- Test: `Tests/WebPicCoreTests/ImageProcessorTests.swift`

**Acceptance Criteria:**
- [ ] `loadCGImage(url:)` / `loadCGImage(data:)` return the full-resolution image
- [ ] `process` with formats {webp, jpeg}, content preset (1200), on a 2000×1000 fixture produces 2 results at 1200×600 with matching formats
- [ ] each result's WebP/JPEG bytes are smaller than the source PNG bytes (real compression)
- [ ] result order follows a stable priority (avif, webp, jpeg, png)

**Verify:** `swift test --filter ImageProcessorTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/ImageProcessorTests.swift`
```swift
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageProcessorTests: XCTestCase {
    private func pngData(_ w: Int, _ h: Int) throws -> Data {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let out = NSMutableData()
        let d = CGImageDestinationCreateWithData(out as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return out as Data
    }

    func testProcessResizesAndEncodes() throws {
        let source = try pngData(2000, 1000)
        var s = Settings.default
        s.preset = .content            // 1200
        s.formats = [.webp, .jpeg]
        s.compressionMode = .quality
        s.quality = 80
        let cg = ImageProcessor().loadCGImage(data: source)!
        let results = try ImageProcessor().process(source: cg, settings: s)
        XCTAssertEqual(results.count, 2)
        for r in results {
            XCTAssertEqual(r.width, 1200)
            XCTAssertEqual(r.height, 600)
            XCTAssertLessThan(r.byteSize, source.count)   // smaller than source PNG
        }
        XCTAssertEqual(results.map(\.format), [.webp, .jpeg])  // priority order
    }
}
```

- [ ] **Step 2: Implement** — `Sources/WebPicCore/Encoding/ImageProcessor.swift`
```swift
import CoreGraphics
import ImageIO
import Foundation

public struct ImageProcessor: Sendable {
    public init() {}

    /// Priority order for output listing.
    static let order: [ImageFormat] = [.avif, .webp, .jpeg, .png]

    func encoder(for format: ImageFormat) -> ImageEncoder {
        format == .webp ? WebPEncoder() : ImageIOEncoder(format: format)
    }

    public func loadCGImage(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
    public func loadCGImage(data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Resize + color-convert once, then encode each selected format at `settings.quality`.
    public func process(source: CGImage, settings: Settings) throws -> [EncodeResult] {
        let targetW = min(Preset.width(for: settings.preset), source.width)
        let resized = ImageResizer.resize(source, toWidth: targetW)
        let converted = ImageResizer.convert(resized, to: settings.colorSpace)
        let q = Double(settings.quality) / 100.0
        let selected = Self.order.filter { settings.formats.contains($0) }
        return try selected.map { fmt in
            let data = try encoder(for: fmt).encode(converted, quality: fmt == .png ? 1 : q)
            return EncodeResult(format: fmt, width: converted.width, height: converted.height,
                                byteSize: data.count, data: data,
                                quality: fmt == .png ? 100 : settings.quality)
        }
    }
}
```

- [ ] **Step 3: Run — PASS**, commit
```bash
swift test --filter ImageProcessorTests
git add Sources/WebPicCore/Encoding/ImageProcessor.swift Tests/WebPicCoreTests/ImageProcessorTests.swift
git commit -m "feat: ImageProcessor (decode/resize/encode pipeline) (M4 task 3)"
```

---

### Task 4: TargetSizeSolver (binary search) + target-mode processing

**Goal:** Binary-search the quality that brings the primary format just under a target byte budget, and add a target-mode process path that encodes all formats at that chosen quality.

**Files:**
- Create: `Sources/WebPicCore/Encoding/TargetSizeSolver.swift`
- Modify: `Sources/WebPicCore/Encoding/ImageProcessor.swift` (add `processForTarget`)
- Test: `Tests/WebPicCoreTests/TargetSizeSolverTests.swift`

**Acceptance Criteria:**
- [ ] `solve(image:encoder:targetBytes:)` returns a quality in 5...100 and data whose size ≤ target (or the min-quality result if the target is infeasible)
- [ ] converges in ≤ 8 iterations
- [ ] `ImageProcessor.processForTarget` returns results for all selected formats at the solved quality, and reports `chosenQuality`

**Verify:** `swift test --filter TargetSizeSolverTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/TargetSizeSolverTests.swift`
```swift
import XCTest
import CoreGraphics
@testable import WebPicCore

final class TargetSizeSolverTests: XCTestCase {
    func testConvergesUnderTarget() throws {
        let img = ImageIOEncoderTests.noisyImage(800, 600)
        let target = 25_000
        let r = try TargetSizeSolver.solve(image: img, encoder: ImageIOEncoder(format: .jpeg),
                                           targetBytes: target, maxIterations: 8)
        XCTAssertLessThanOrEqual(r.data.count, target)
        XCTAssertGreaterThanOrEqual(r.quality, 5)
        XCTAssertLessThanOrEqual(r.quality, 100)
    }

    func testProcessForTargetUsesSolvedQuality() throws {
        let img = ImageIOEncoderTests.noisyImage(1600, 1000)
        var s = Settings.default
        s.preset = .content
        s.formats = [.jpeg, .webp]
        s.compressionMode = .target
        s.targetValue = "40"; s.targetUnit = .kb    // 40 KB budget on primary (webp)
        let out = try ImageProcessor().processForTarget(source: img, settings: s)
        XCTAssertEqual(Set(out.results.map(\.format)), [.jpeg, .webp])
        XCTAssertGreaterThanOrEqual(out.chosenQuality, 5)
        XCTAssertLessThanOrEqual(out.chosenQuality, 100)
    }
}
```

- [ ] **Step 2: TargetSizeSolver** — `Sources/WebPicCore/Encoding/TargetSizeSolver.swift`
```swift
import CoreGraphics
import Foundation

public enum TargetSizeSolver {
    public struct Solution: Sendable { public let quality: Int; public let data: Data }

    /// Binary search quality (5...100) so encoded size ≤ targetBytes; if infeasible, returns the smallest (min-quality) result.
    public static func solve(image: CGImage, encoder: ImageEncoder,
                             targetBytes: Int, maxIterations: Int = 8) throws -> Solution {
        var lo = 5, hi = 100
        var best: Solution? = nil          // best under-target (highest quality that fits)
        var smallest: Solution? = nil      // fallback: smallest overall
        var iterations = 0
        while lo <= hi && iterations < maxIterations {
            iterations += 1
            let mid = (lo + hi) / 2
            let data = try encoder.encode(image, quality: Double(mid) / 100.0)
            if smallest == nil || data.count < smallest!.data.count {
                smallest = Solution(quality: mid, data: data)
            }
            if data.count <= targetBytes {
                best = Solution(quality: mid, data: data)
                lo = mid + 1               // try higher quality
            } else {
                hi = mid - 1               // need smaller
            }
        }
        if let best { return best }
        return smallest ?? Solution(quality: 5, data: try encoder.encode(image, quality: 0.05))
    }
}
```

- [ ] **Step 3: processForTarget** — add to `ImageProcessor`:
```swift
    public struct TargetOutput: Sendable { public let results: [EncodeResult]; public let chosenQuality: Int }

    /// Target-file-size mode: solve quality on the primary format, encode all selected formats at it.
    public func processForTarget(source: CGImage, settings: Settings) throws -> TargetOutput {
        let targetW = min(Preset.width(for: settings.preset), source.width)
        let resized = ImageResizer.resize(source, toWidth: targetW)
        let converted = ImageResizer.convert(resized, to: settings.colorSpace)
        let targetBytes = Int(EstimationService.targetBytes(settings))
        let primary = EstimationService.primaryFormat(settings.formats)
        let solution = try TargetSizeSolver.solve(image: converted, encoder: encoder(for: primary),
                                                  targetBytes: max(1, targetBytes))
        let q = Double(solution.quality) / 100.0
        let selected = Self.order.filter { settings.formats.contains($0) }
        let results = try selected.map { fmt -> EncodeResult in
            let data = fmt == primary
                ? solution.data
                : try encoder(for: fmt).encode(converted, quality: fmt == .png ? 1 : q)
            return EncodeResult(format: fmt, width: converted.width, height: converted.height,
                                byteSize: data.count, data: data,
                                quality: fmt == .png ? 100 : solution.quality)
        }
        return TargetOutput(results: results, chosenQuality: solution.quality)
    }
```

- [ ] **Step 4: Run — PASS**, commit
```bash
swift test --filter TargetSizeSolverTests
git add Sources/WebPicCore/Encoding/TargetSizeSolver.swift Sources/WebPicCore/Encoding/ImageProcessor.swift Tests/WebPicCoreTests/TargetSizeSolverTests.swift
git commit -m "feat: TargetSizeSolver binary search + target-mode processing (M4 task 4)"
```

---

## Milestone 4 acceptance
- [ ] `swift build` + `swift test` green (all prior tests still pass)
- [ ] Real encode to WebP (libwebp), AVIF/JPEG/PNG (ImageIO) — outputs decode correctly at the right dimensions
- [ ] Quality parameter measurably changes size; resize preserves aspect and never upscales
- [ ] Target-size binary search meets the budget (or returns the smallest feasible) and reports the chosen quality
- [ ] An integration test demonstrates real files smaller than the source

## Notes for later milestones
- **M5** wires `ImageProcessor` results into the Preview/Compare/Export UI and the Save flow (NSSavePanel/Photos/Share), and surfaces `chosenQuality` in the Export review. It must also retain original bytes for Photos-origin images (currently only `url` images can be re-read at full res) — add `WebPicImage.sourceData` or re-load, decided in M5.
- **M6** applies the filename scheme + responsive `srcset` widths to real outputs.
- WebP alpha uses premultiplied RGBA (fine for typical images); revisit straight-alpha if edge artifacts appear.
- Metadata (EXIF/ICC) preservation is currently limited to color-space conversion; full EXIF copy-through can be added when the Save flow lands (M5/M6).
