# WebPic Milestone 3 — Settings Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the full Settings screen from the reference — Ausgabe segmented, Preset cards, Format toggles, Komprimierung (quality slider ↔ target-size with error/ok states), Responsive breakpoints, Advanced (metadata/colorspace/filename), and the live-preview column — driven by a pure `EstimationService` that ports the reference's estimate heuristics (mock encoder; real encoder is M4).

**Architecture:** Refactor `Settings` to hold independent `compressionMode` / `quality` / `targetValue` / `targetUnit` (mirrors the reference `DCLogic` state so switching modes preserves values). A pure, unit-tested `EstimationService` reproduces the reference math exactly. `AppStore` gains settings-intent methods (preset selection sets quality, format toggle). The Settings UI uses native controls (`Picker(.segmented)`, `Slider`, `Toggle`, `TextField`) with custom preset cards / format chips, reading `@Bindable` store + `@Environment(\.wpPalette)`.

**Tech Stack:** Swift 6, SwiftUI (macOS 14+), Observation.

**Reference:** [`docs/design-reference/WebPic.dc.html`](../../design-reference/WebPic.dc.html) (SETTINGS block lines ~168–342; heuristics in the `DCLogic` script lines ~552–569). Spec: [`docs/superpowers/specs/2026-07-01-webpic-design.md`](../specs/2026-07-01-webpic-design.md). Builds on M1 + M2.

**Native deviations (native wins):** native segmented pickers/sliders/toggles instead of the HTML custom controls; the preview column is fixed on the right while the left column scrolls (approximating the HTML `position:sticky`).

---

### Task 0: Settings model refactor (independent compression fields)

**Goal:** Replace the `compression` enum with independent `compressionMode`/`quality`/`targetValue`/`targetUnit`, matching the reference state so switching modes preserves both values.

**Files:**
- Modify: `Sources/WebPicCore/Models/Enums.swift` (remove `Compression`, add `CompressionMode`)
- Modify: `Sources/WebPicCore/Models/Settings.swift`
- Modify: `Tests/WebPicCoreTests/SettingsTests.swift`

**Acceptance Criteria:**
- [ ] `Settings` has `compressionMode: CompressionMode`, `quality: Int`, `targetValue: String`, `targetUnit: SizeUnit`
- [ ] `Settings.default` = single, hero, [webp,jpeg], `.quality`, quality 78, targetValue "200", `.kb`, breakpoints [400,800,1200], sRGB, keepMetadata false, `{name}-{w}.{format}`
- [ ] Codable round-trip holds; `grep -rn "\.compression\b\|case quality(\|case target(" Sources` returns nothing (old enum gone)
- [ ] full `swift test` green

**Verify:** `swift test --filter SettingsTests`

**Steps:**

- [ ] **Step 1: Enums** — in `Sources/WebPicCore/Models/Enums.swift`, DELETE the `Compression` enum and ADD:
```swift
public enum CompressionMode: String, Codable, CaseIterable, Sendable { case quality, target }
```
(Keep `Tab`, `OutputMode`, `ImageFormat`, `SizeUnit`, `ColorSpace` as-is.)

- [ ] **Step 2: Settings** — replace `Sources/WebPicCore/Models/Settings.swift` with:
```swift
import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var outputMode: OutputMode
    public var preset: Preset.Key
    public var formats: Set<ImageFormat>
    public var compressionMode: CompressionMode
    public var quality: Int
    public var targetValue: String
    public var targetUnit: SizeUnit
    public var breakpoints: Set<Int>
    public var customBreakpoint: Int?
    public var colorSpace: ColorSpace
    public var keepMetadata: Bool
    public var filenameScheme: String

    public static let `default` = Settings(
        outputMode: .single,
        preset: .hero,
        formats: [.webp, .jpeg],
        compressionMode: .quality,
        quality: 78,
        targetValue: "200",
        targetUnit: .kb,
        breakpoints: [400, 800, 1200],
        customBreakpoint: nil,
        colorSpace: .sRGB,
        keepMetadata: false,
        filenameScheme: "{name}-{w}.{format}"
    )
}
```

- [ ] **Step 3: Update SettingsTests** — replace the compression-related assertions in `Tests/WebPicCoreTests/SettingsTests.swift`:
```swift
    func testCodableRoundTrip() throws {
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = "150"
        s.targetUnit = .mb
        s.formats = [.webp, .avif]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testDefaults() {
        let s = Settings.default
        XCTAssertEqual(s.outputMode, .single)
        XCTAssertEqual(s.preset, .hero)
        XCTAssertEqual(s.formats, [.webp, .jpeg])
        XCTAssertEqual(s.compressionMode, .quality)
        XCTAssertEqual(s.quality, 78)
        XCTAssertEqual(s.targetValue, "200")
        XCTAssertEqual(s.targetUnit, .kb)
    }
```
(Keep `testPresetTable` unchanged.)

- [ ] **Step 4: Verify + commit**

```bash
swift test && grep -rn "\.compression\b" Sources || echo "no stale compression refs"
git add Sources/WebPicCore/Models Tests/WebPicCoreTests/SettingsTests.swift
git commit -m "refactor: Settings independent compression fields (M3 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: EstimationService (port reference heuristics)

**Goal:** A pure, unit-tested service reproducing the reference estimate math exactly (format factors, area factor, estimated bytes, savings, target-size parsing/feasibility, auto-quality, new dimensions).

**Files:**
- Create: `Sources/WebPicCore/Estimation/EstimationService.swift`
- Test: `Tests/WebPicCoreTests/EstimationServiceTests.swift`

**Acceptance Criteria (exact reference formulas):**
- [ ] `formatFactor`: avif 0.30, webp 0.44, jpeg 0.64, png 0.90
- [ ] `primaryFormat`: avif→.avif, else webp→.webp, else jpeg→.jpeg, else png→.png, else .webp
- [ ] `estimatedBytes` quality mode: `max(8000, round(bytes · areaFactor · formatFactor · (0.14 + quality/100·0.86)))`
- [ ] `estimatedBytes` target mode: the target bytes (≥1), else 12000
- [ ] `targetBytes`: parse `targetValue` (comma→dot); `.kb`→×1024, `.mb`→×1048576; NaN when unparseable
- [ ] `targetError`: true when not parseable/≤0 or `< feasibleMin` (`max(8000, bytes·area·fmt·0.10)`)
- [ ] `autoQuality`: `clamp(5...100, round((targetBytes/(bytes·area·fmt) − 0.14)/0.86 · 100))`
- [ ] `newDimensions`: `tw = min(presetWidth, imageWidth)`, `(tw, round(tw·h/w))`
- [ ] `savingsPercent`: `max(0, round((1 − estimatedBytes/bytes)·100))`

**Verify:** `swift test --filter EstimationServiceTests`

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/EstimationServiceTests.swift`

```swift
import XCTest
@testable import WebPicCore

final class EstimationServiceTests: XCTestCase {
    // hero-banner.jpg reference image
    private func hero() -> WebPicImage {
        WebPicImage(id: "i1", name: "hero-banner.jpg", pixelWidth: 4032, pixelHeight: 2268,
                    byteSize: 6_083_000, status: .done)
    }

    func testFormatFactors() {
        XCTAssertEqual(EstimationService.formatFactor(.avif), 0.30, accuracy: 0.0001)
        XCTAssertEqual(EstimationService.formatFactor(.webp), 0.44, accuracy: 0.0001)
        XCTAssertEqual(EstimationService.formatFactor(.jpeg), 0.64, accuracy: 0.0001)
        XCTAssertEqual(EstimationService.formatFactor(.png), 0.90, accuracy: 0.0001)
    }

    func testPrimaryFormat() {
        XCTAssertEqual(EstimationService.primaryFormat([.jpeg, .avif, .webp]), .avif)
        XCTAssertEqual(EstimationService.primaryFormat([.jpeg, .webp]), .webp)
        XCTAssertEqual(EstimationService.primaryFormat([.jpeg]), .jpeg)
        XCTAssertEqual(EstimationService.primaryFormat([.png]), .png)
        XCTAssertEqual(EstimationService.primaryFormat([]), .webp)
    }

    func testEstimatedBytesQuality() {
        var s = Settings.default            // hero preset 1920, webp+jpeg (primary webp), quality 78
        s.quality = 78
        // areaFactor = (1920/4032)^2 ; fmt = 0.44 ; q = 0.14 + 0.78*0.86
        let area = pow(1920.0 / 4032.0, 2)
        let expected = max(8000, Int((6_083_000.0 * area * 0.44 * (0.14 + 0.78 * 0.86)).rounded()))
        XCTAssertEqual(EstimationService.estimatedBytes(image: hero(), settings: s), expected)
    }

    func testNewDimensions() {
        let d = EstimationService.newDimensions(image: hero(), settings: .default)
        XCTAssertEqual(d.width, 1920)
        XCTAssertEqual(d.height, Int((1920.0 * 2268.0 / 4032.0).rounded()))
    }

    func testTargetBytesAndError() {
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = "200"; s.targetUnit = .kb
        XCTAssertEqual(EstimationService.targetBytes(s), 200 * 1024, accuracy: 0.5)
        // 200KB is well above feasibleMin for hero → no error
        XCTAssertFalse(EstimationService.targetError(image: hero(), settings: s))
        s.targetValue = "1"   // 1KB → below feasibleMin → error
        XCTAssertTrue(EstimationService.targetError(image: hero(), settings: s))
        s.targetValue = "abc" // unparseable → error
        XCTAssertTrue(EstimationService.targetError(image: hero(), settings: s))
    }

    func testAutoQualityClamped() {
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = "5"; s.targetUnit = .kb    // very small → clamps to 5
        XCTAssertEqual(EstimationService.autoQuality(image: hero(), settings: s), 5)
    }

    func testSavingsPercent() {
        let pct = EstimationService.savingsPercent(image: hero(), settings: .default)
        XCTAssertGreaterThan(pct, 0)
        XCTAssertLessThanOrEqual(pct, 100)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**, then implement `Sources/WebPicCore/Estimation/EstimationService.swift`:

```swift
import Foundation

public enum EstimationService {
    public static func formatFactor(_ f: ImageFormat) -> Double {
        switch f {
        case .avif: return 0.30
        case .webp: return 0.44
        case .jpeg: return 0.64
        case .png:  return 0.90
        }
    }

    public static func primaryFormat(_ formats: Set<ImageFormat>) -> ImageFormat {
        if formats.contains(.avif) { return .avif }
        if formats.contains(.webp) { return .webp }
        if formats.contains(.jpeg) { return .jpeg }
        if formats.contains(.png)  { return .png }
        return .webp
    }

    public static func presetWidth(_ settings: Settings) -> Int {
        Preset.width(for: settings.preset)
    }

    static func targetWidth(image: WebPicImage, settings: Settings) -> Int {
        min(presetWidth(settings), image.pixelWidth)
    }

    static func areaFactor(image: WebPicImage, settings: Settings) -> Double {
        let tw = Double(targetWidth(image: image, settings: settings))
        let w = Double(image.pixelWidth)
        guard w > 0 else { return 1 }
        return pow(tw / w, 2)
    }

    public static func targetBytes(_ settings: Settings) -> Double {
        let normalized = settings.targetValue.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(normalized) else { return .nan }
        return settings.targetUnit == .mb ? v * 1_048_576 : v * 1024
    }

    static func feasibleMin(image: WebPicImage, settings: Settings) -> Double {
        let base = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(primaryFormat(settings.formats))
        return max(8000, base * 0.10)
    }

    public static func targetError(image: WebPicImage, settings: Settings) -> Bool {
        guard settings.compressionMode == .target else { return false }
        let tb = targetBytes(settings)
        if tb.isNaN || tb <= 0 { return true }
        return tb < feasibleMin(image: image, settings: settings)
    }

    public static func autoQuality(image: WebPicImage, settings: Settings) -> Int {
        let base = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(primaryFormat(settings.formats))
        guard base > 0 else { return 5 }
        let q = (targetBytes(settings) / base - 0.14) / 0.86 * 100
        return max(5, min(100, Int(q.rounded())))
    }

    public static func estimatedBytes(image: WebPicImage, settings: Settings) -> Int {
        if settings.compressionMode == .target {
            let tb = targetBytes(settings)
            return tb > 0 ? Int(tb) : 12000
        }
        let q = 0.14 + Double(settings.quality) / 100 * 0.86
        let b = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(primaryFormat(settings.formats))
            * q
        return max(8000, Int(b.rounded()))
    }

    public static func savingsPercent(image: WebPicImage, settings: Settings) -> Int {
        guard image.byteSize > 0 else { return 0 }
        let ratio = 1 - Double(estimatedBytes(image: image, settings: settings)) / Double(image.byteSize)
        return max(0, Int((ratio * 100).rounded()))
    }

    public static func newDimensions(image: WebPicImage, settings: Settings) -> (width: Int, height: Int) {
        let tw = targetWidth(image: image, settings: settings)
        guard image.pixelWidth > 0 else { return (tw, 0) }
        let h = Double(tw) * Double(image.pixelHeight) / Double(image.pixelWidth)
        return (tw, Int(h.rounded()))
    }
}
```

- [ ] **Step 3: Run — expect PASS**, then commit

```bash
swift test --filter EstimationServiceTests
git add Sources/WebPicCore/Estimation Tests/WebPicCoreTests/EstimationServiceTests.swift
git commit -m "feat: EstimationService (reference estimate heuristics) (M3 task 1)"
```

---

### Task 2: AppStore settings intents

**Goal:** Intent methods for the settings that carry logic: selecting a preset sets quality to the preset default; toggling a format flips membership. Both persist.

**Files:**
- Modify: `Sources/WebPicCore/AppStore.swift`
- Test: `Tests/WebPicCoreTests/AppStoreSettingsTests.swift`

**Acceptance Criteria:**
- [ ] `selectPreset(_:)` sets `settings.preset` and `settings.quality = Preset.defaultQuality(for:)`
- [ ] `toggleFormat(_:)` inserts/removes the format in `settings.formats`
- [ ] both trigger `settings` `didSet` persistence (settings survive a reload with same defaults)

**Verify:** `swift test --filter AppStoreSettingsTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/AppStoreSettingsTests.swift`

```swift
import XCTest
@testable import WebPicCore

@MainActor
final class AppStoreSettingsTests: XCTestCase {
    private func store(_ d: UserDefaults) -> AppStore { AppStore(defaults: d) }

    func testSelectPresetSetsQuality() {
        let s = store(UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        s.selectPreset(.thumb)
        XCTAssertEqual(s.settings.preset, .thumb)
        XCTAssertEqual(s.settings.quality, 65)   // thumb default
        s.selectPreset(.icon)
        XCTAssertEqual(s.settings.quality, 90)   // icon default
    }

    func testToggleFormat() {
        let s = store(UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        XCTAssertTrue(s.settings.formats.contains(.webp))
        s.toggleFormat(.webp)
        XCTAssertFalse(s.settings.formats.contains(.webp))
        s.toggleFormat(.avif)
        XCTAssertTrue(s.settings.formats.contains(.avif))
    }

    func testSettingsPersist() {
        let d = UserDefaults(suiteName: "wp.\(UUID().uuidString)")!
        let s = store(d)
        s.selectPreset(.content)
        let reloaded = store(d)
        XCTAssertEqual(reloaded.settings.preset, .content)
        XCTAssertEqual(reloaded.settings.quality, 72)
    }
}
```

- [ ] **Step 2: Implement** — add to `AppStore` (methods; `settings` already has a persisting `didSet`):
```swift
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
```
> Note: mutating two properties of the `settings` struct fires the `didSet` twice (two persists) — acceptable. If you prefer a single persist, mutate a local copy then assign once; either is fine as long as tests pass.

- [ ] **Step 3: Run — expect PASS**, then commit

```bash
swift test --filter AppStoreSettingsTests && swift build
git add Sources/WebPicCore/AppStore.swift Tests/WebPicCoreTests/AppStoreSettingsTests.swift
git commit -m "feat: AppStore settings intents (selectPreset, toggleFormat) (M3 task 2)"
```

---

### Task 3: SettingsView scaffold + Ausgabe/Preset/Format + preview column

**Goal:** Replace `SettingsPlaceholderView` with a two-column `SettingsView`: left column with Ausgabe segmented, Preset cards, Format chips (rest stubbed); right fixed preview column driven by `EstimationService`. Wire into routing so it's viewable.

**Files:**
- Create: `Sources/WebPicApp/Settings/SettingsView.swift`
- Create: `Sources/WebPicApp/Settings/PresetCards.swift`
- Create: `Sources/WebPicApp/Settings/FormatChips.swift`
- Create: `Sources/WebPicApp/Settings/PreviewColumn.swift`
- Create: `Sources/WebPicApp/Shared/WPSection.swift`
- Modify: `Sources/WebPicApp/MainView.swift` (route settings tab → `SettingsView`)

**Acceptance Criteria:**
- [ ] Settings tab shows Ausgabe segmented (Einzelbild/Responsive Set/Nur Konvertierung), Preset cards (5, horizontally scrolling, selected = accent ring), Format chips (WebP/AVIF/JPEG-Fallback/PNG, multi, selected = accent tint)
- [ ] Right preview column shows Original→Optimiert sizes, savings bar + −%, Auflösung orig→new, primary format — all live from `EstimationService`
- [ ] Selecting a preset updates the preview; toggling formats updates it
- [ ] `swift build` succeeds

**Verify:** `swift build` (visual in Task 5 screenshot; can also screenshot here)

**Steps:**

- [ ] **Step 1: Section helper** — `Sources/WebPicApp/Shared/WPSection.swift`
```swift
import SwiftUI
import WebPicCore

/// Uppercase section label used above settings groups.
struct WPSectionLabel: View {
    @Environment(\.wpPalette) private var p
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold)).kerning(0.3)
            .foregroundStyle(p.t3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.bottom, 8)
    }
}

extension View {
    /// Card container: card fill, 12 radius, hairline border, soft shadow.
    func wpCard(_ p: WPPalette) -> some View {
        self.background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.sep, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }
}
```

- [ ] **Step 2: Preset cards** — `Sources/WebPicApp/Settings/PresetCards.swift`
```swift
import SwiftUI
import WebPicCore

struct PresetCards: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    // Icon gradient per preset (from reference).
    private func gradient(_ key: Preset.Key) -> [UInt32] {
        switch key {
        case .hero:    return [0x0A84FF, 0x5E5CE6]
        case .content: return [0x30D158, 0x0FB5AE]
        case .thumb:   return [0xFF9F0A, 0xFF375F]
        case .icon:    return [0xBF5AF2, 0x5E5CE6]
        case .custom:  return [0x8E8E93, 0x636366]
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Preset.all) { preset in
                    let on = store.settings.preset == preset.key
                    Button { store.selectPreset(preset.key) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: gradient(preset.key).map { Color(hex: $0) },
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .padding(.bottom, 6)
                            Text(preset.label).font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(p.t1)
                            Text(preset.sub).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
                        }
                        .frame(minWidth: 132, alignment: .leading)
                        .padding(12)
                        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(on ? p.accent : p.sep, lineWidth: on ? 1.5 : 0.5))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(on ? p.accentTint : .clear, lineWidth: 3).padding(-1.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 2)
        }
    }
}
```

- [ ] **Step 3: Format chips** — `Sources/WebPicApp/Settings/FormatChips.swift`
```swift
import SwiftUI
import WebPicCore

struct FormatChips: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private let defs: [(ImageFormat, String)] =
        [(.webp, "WebP"), (.avif, "AVIF"), (.jpeg, "JPEG-Fallback"), (.png, "PNG")]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(defs, id: \.0) { fmt, label in
                let on = store.settings.formats.contains(fmt)
                Button { store.toggleFormat(fmt) } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(on ? p.accent : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(on ? p.accent : p.ctrlBorder, lineWidth: 1.5))
                            .frame(width: 15, height: 15)
                            .overlay { if on {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            } }
                        Text(label).font(.system(size: 13, weight: on ? .medium : .regular))
                            .foregroundStyle(on ? p.accent : p.t1)
                    }
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(on ? p.accentTint : p.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(on ? p.accent : p.sep2, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 4: Preview column** — `Sources/WebPicApp/Settings/PreviewColumn.swift`
```swift
import SwiftUI
import WebPicCore

struct PreviewColumn: View {
    let image: WebPicImage
    let settings: Settings
    @Environment(\.wpPalette) private var p

    private var estBytes: Int { EstimationService.estimatedBytes(image: image, settings: settings) }
    private var savings: Int { EstimationService.savingsPercent(image: image, settings: settings) }
    private var newDims: (width: Int, height: Int) { EstimationService.newDimensions(image: image, settings: settings) }
    private var primary: ImageFormat { EstimationService.primaryFormat(settings.formats) }

    var body: some View {
        VStack(spacing: 0) {
            // Preview image + badge
            ThumbnailView(image: image, cornerRadius: 0)
                .frame(height: 180).frame(maxWidth: .infinity).clipped()
                .overlay(alignment: .topLeading) {
                    Text("VORSCHAU").font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white).padding(10)
                }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Original").font(.system(size: 11)).foregroundStyle(p.t3)
                        Text(formatBytes(image.byteSize)).font(.system(size: 14, weight: .medium).monospacedDigit())
                    }
                    Spacer()
                    Image(systemName: "arrow.right").foregroundStyle(p.t3).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Optimiert").font(.system(size: 11)).foregroundStyle(p.accent)
                        Text(formatBytes(estBytes)).font(.system(size: 14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(p.accent)
                    }
                }
                .padding(.bottom, 12)
                // savings bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(p.seg)
                        Capsule().fill(LinearGradient(colors: [p.accent, Color(hex: 0x5AC8FA)],
                                                      startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(savings) / 100)
                    }
                }
                .frame(height: 8).padding(.bottom, 8)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("−\(savings)%").font(.system(size: 26, weight: .semibold).monospacedDigit())
                    Text("kleiner · spart \(formatBytes(max(0, image.byteSize - estBytes)))")
                        .font(.system(size: 12)).foregroundStyle(p.t2)
                }
                .padding(.bottom, 14)
                Divider()
                row("Auflösung", "\(image.pixelWidth)×\(image.pixelHeight) → \(newDims.width)×\(newDims.height)", mono: true)
                row("Format", primary.displayName, mono: false)
            }
            .padding(.horizontal, 15).padding(.top, 14).padding(.bottom, 16)
        }
        .wpCard(p)
        .frame(width: 300)
    }

    @ViewBuilder private func row(_ label: String, _ value: String, mono: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(p.t2)
            Spacer()
            Text(value).font(mono ? .system(size: 12).monospacedDigit() : .system(size: 12, weight: .medium))
                .foregroundStyle(p.t1)
        }
        .padding(.top, 8)
    }
}
```
Add a display name for `ImageFormat` — in `Sources/WebPicCore/Models/Enums.swift`, extend:
```swift
public extension ImageFormat {
    var displayName: String {
        switch self { case .webp: return "WebP"; case .avif: return "AVIF"; case .jpeg: return "JPEG"; case .png: return "PNG" }
    }
}
```

- [ ] **Step 5: SettingsView** — `Sources/WebPicApp/Settings/SettingsView.swift`
```swift
import SwiftUI
import WebPicCore

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Ausgabe
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Ausgabe")
                        Picker("", selection: $store.settings.outputMode) {
                            Text("Einzelbild").tag(OutputMode.single)
                            Text("Responsive Set").tag(OutputMode.responsive)
                            Text("Nur Konvertierung").tag(OutputMode.convert)
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }
                    // Preset
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Preset")
                        PresetCards(store: store)
                    }
                    // Format
                    VStack(alignment: .leading, spacing: 0) {
                        WPSectionLabel(text: "Format")
                        FormatChips(store: store)
                    }
                    // (Compression card = Task 4; Breakpoints + Advanced = Task 5)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 28).padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let img = store.selected {
                PreviewColumn(image: img, settings: store.settings)
                    .padding(.trailing, 28).padding(.top, 26)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.grouped)
    }
}
```

- [ ] **Step 6: Route it** — in `Sources/WebPicApp/MainView.swift`, replace the non-empty branch so the settings tab uses `SettingsView`:
```swift
        Group {
            if store.isEmpty {
                EmptyImportView()
            } else if store.tab == .compare {
                SettingsPlaceholderView()      // Compare = M5
            } else if store.tab == .export {
                SettingsPlaceholderView()      // Export = M5
            } else if store.tab == .batch {
                SettingsPlaceholderView()      // Batch = M7
            } else {
                SettingsView(store: store)
            }
        }
```
Add `@Bindable var store = store` where needed, or since MainView reads `@Environment(AppStore.self) private var store`, pass it: `SettingsView(store: store)` works because `SettingsView` takes an `AppStore` and marks it `@Bindable` internally.

- [ ] **Step 7: Build + commit**

```bash
swift build
git add Sources/WebPicApp/Settings Sources/WebPicApp/Shared/WPSection.swift Sources/WebPicApp/MainView.swift Sources/WebPicCore/Models/Enums.swift
git commit -m "feat: SettingsView scaffold + Ausgabe/Preset/Format + preview column (M3 task 3)"
```

---

### Task 4: Compression card (quality slider ↔ target size)

**Goal:** The Komprimierung card — header + `Qualität | Zieldateigröße` segmented; quality mode = slider + big % + live "Geschätzte Ausgabe"; target mode = KB/MB field with error ("Zu klein – realistisch sind mind. X") and ok ("Qualität wird automatisch auf ≈X% gesetzt") states.

**Files:**
- Create: `Sources/WebPicApp/Settings/CompressionCard.swift`
- Modify: `Sources/WebPicApp/Settings/SettingsView.swift` (insert after Format)

**Acceptance Criteria:**
- [ ] Segmented switches `store.settings.compressionMode`
- [ ] Quality mode: slider bound to `settings.quality` (0–100), big `%` value, and "Geschätzte Ausgabe — <estSize> · −<savings>%"
- [ ] Target mode: numeric field bound to `settings.targetValue`, KB/MB segmented; shows the red error line when `EstimationService.targetError` is true, else the auto-quality hint
- [ ] `swift build` succeeds

**Verify:** `swift build`

**Steps:**

- [ ] **Step 1: CompressionCard** — `Sources/WebPicApp/Settings/CompressionCard.swift`
```swift
import SwiftUI
import WebPicCore

struct CompressionCard: View {
    @Bindable var store: AppStore
    let image: WebPicImage
    @Environment(\.wpPalette) private var p

    private var s: Settings { store.settings }
    private var estBytes: Int { EstimationService.estimatedBytes(image: image, settings: s) }
    private var savings: Int { EstimationService.savingsPercent(image: image, settings: s) }
    private var hasError: Bool { EstimationService.targetError(image: image, settings: s) }
    private var autoQ: Int { EstimationService.autoQuality(image: image, settings: s) }

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
            if s.compressionMode == .quality {
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
                    Text("\(s.quality)").font(.system(size: 20, weight: .medium).monospacedDigit())
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
        let tb = EstimationService.targetBytes(s)
        if tb.isNaN || tb <= 0 { return "Bitte eine gültige Zahl eingeben" }
        return "Zu klein – realistisch sind mind. \(formatBytes(Int(EstimationService.feasibleMinPublic(image: image, settings: s))))"
    }
}
```
Expose `feasibleMin` for the message — in `EstimationService`, add:
```swift
    public static func feasibleMinPublic(image: WebPicImage, settings: Settings) -> Double {
        feasibleMin(image: image, settings: settings)
    }
```

- [ ] **Step 2: Insert into SettingsView** — after the Format section `VStack`, add:
```swift
                    if let img = store.selected {
                        CompressionCard(store: store, image: img)
                    }
```

- [ ] **Step 3: Build + commit**
```bash
swift build
git add Sources/WebPicApp/Settings/CompressionCard.swift Sources/WebPicApp/Settings/SettingsView.swift Sources/WebPicCore/Estimation/EstimationService.swift
git commit -m "feat: compression card (quality slider + target size) (M3 task 4)"
```

---

### Task 5: Breakpoints (responsive) + Advanced card + screenshot

**Goal:** The responsive Breakpoints card (shown only when `outputMode == .responsive`) and the collapsible Advanced card (metadata toggle, colorspace segmented, filename scheme). Final assembly + screenshot verification.

**Files:**
- Create: `Sources/WebPicApp/Settings/BreakpointsCard.swift`
- Create: `Sources/WebPicApp/Settings/AdvancedCard.swift`
- Modify: `Sources/WebPicApp/Settings/SettingsView.swift`

**Acceptance Criteria:**
- [ ] Breakpoints card visible only when `outputMode == .responsive`; checkboxes 400/800/1200/1920 with notes (Mobil/Tablet/Desktop/Retina) toggle `settings.breakpoints`; custom-width field bound to `settings.customBreakpoint`
- [ ] Advanced card is collapsible; Metadaten behalten `Toggle`, Farbraum sRGB/Display P3 segmented, Dateinamen-Schema `TextField`
- [ ] `swift build` succeeds; screenshot shows the full settings screen (single + responsive, light + dark)

**Verify:** `swift build && bash Scripts/bundle.sh` → controller screenshots.

**Steps:**

- [ ] **Step 1: BreakpointsCard** — `Sources/WebPicApp/Settings/BreakpointsCard.swift`
```swift
import SwiftUI
import WebPicCore

struct BreakpointsCard: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var customText: String = ""

    private let defs: [(Int, String)] = [(400, "Mobil"), (800, "Tablet"), (1200, "Desktop"), (1920, "Retina / Hero")]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Breakpoints").font(.system(size: 14, weight: .semibold)); Spacer() }
                .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 11)
            Divider()
            ForEach(defs, id: \.0) { w, note in
                let on = store.settings.breakpoints.contains(w)
                Button {
                    if on { store.settings.breakpoints.remove(w) } else { store.settings.breakpoints.insert(w) }
                } label: {
                    HStack(spacing: 11) {
                        checkbox(on)
                        Text("\(w)w").font(.system(size: 13, weight: .medium).monospacedDigit()).foregroundStyle(p.t1)
                        Spacer()
                        Text(note).font(.system(size: 12)).foregroundStyle(p.t3)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(p.ctrlBorder, lineWidth: 1.5).frame(width: 19, height: 19)
                Text("Eigene Breite").font(.system(size: 13)).foregroundStyle(p.t2)
                Spacer()
                TextField("z. B. 640", text: $customText)
                    .textFieldStyle(.plain).font(.system(size: 13).monospacedDigit())
                    .frame(width: 82, height: 28).padding(.horizontal, 9)
                    .background(p.field, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
                    .onChange(of: customText) { _, v in store.settings.customBreakpoint = Int(v) }
                Text("w").font(.system(size: 12).monospacedDigit()).foregroundStyle(p.t3)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
        }
        .wpCard(p)
    }

    @ViewBuilder private func checkbox(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(on ? p.accent : .clear)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(on ? p.accent : p.ctrlBorder, lineWidth: 1.5))
            .frame(width: 19, height: 19)
            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
    }
}
```

- [ ] **Step 2: AdvancedCard** — `Sources/WebPicApp/Settings/AdvancedCard.swift`
```swift
import SwiftUI
import WebPicCore

struct AdvancedCard: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.18)) { open.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(p.t2).rotationEffect(.degrees(open ? 90 : 0))
                    Text("Erweitert").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.t1)
                    Spacer()
                    Text("Metadaten, Farbraum, Dateiname").font(.system(size: 12)).foregroundStyle(p.t3)
                }
                .padding(.horizontal, 16).padding(.vertical, 13).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if open {
                Divider()
                row {
                    labelPair("Metadaten behalten", "EXIF, Copyright & Farbprofil")
                    Toggle("", isOn: $store.settings.keepMetadata).labelsHidden().toggleStyle(.switch).tint(p.accent)
                }
                Divider()
                row {
                    labelPair("Farbraum", "Für Web meist sRGB empfohlen")
                    Picker("", selection: $store.settings.colorSpace) {
                        Text("sRGB").tag(ColorSpace.sRGB); Text("Display P3").tag(ColorSpace.displayP3)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                Divider()
                row {
                    labelPair("Dateinamen-Schema", "Platzhalter: {name} {w} {format}")
                    TextField("", text: $store.settings.filenameScheme)
                        .textFieldStyle(.plain).font(.system(size: 12).monospacedDigit())
                        .frame(width: 200, height: 28).padding(.horizontal, 9)
                        .background(p.field, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
                }
            }
        }
        .wpCard(p)
    }

    @ViewBuilder private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 12) { content() }.padding(.horizontal, 16).padding(.vertical, 13)
    }
    @ViewBuilder private func labelPair(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(p.t1)
            Text(sub).font(.system(size: 12)).foregroundStyle(p.t3)
        }
        Spacer()
    }
}
```

- [ ] **Step 3: Insert into SettingsView** — after the CompressionCard block, add:
```swift
                    if store.settings.outputMode == .responsive {
                        BreakpointsCard(store: store)
                    }
                    AdvancedCard(store: store)
```

- [ ] **Step 4: Build, bundle, screenshot, commit**
```bash
swift build && swift test && bash Scripts/bundle.sh
git add Sources/WebPicApp/Settings
git commit -m "feat: breakpoints + advanced cards; full settings screen (M3 task 5)"
```
Controller then screenshots: seeded/imported image, settings tab, single + responsive modes, light + dark, comparing to the reference SETTINGS block.

---

## Milestone 3 acceptance
- [ ] `swift build` + `swift test` green (M1/M2 tests still pass)
- [ ] Settings screen matches the reference: Ausgabe, Preset cards, Format chips, Komprimierung (quality slider + target with error/ok), Responsive breakpoints, Advanced
- [ ] Live preview column reflects preset/format/quality/target changes via `EstimationService`
- [ ] Light + dark correct; screenshot verified

## Notes for later milestones
- Estimates are heuristic (mock). M4 swaps `EstimationService` display for real encode results on Compare/Export.
- Custom preset width & custom breakpoint are captured but the encoder honoring them is M4/M6.
- Compare (M5) and Export (M5) still route to the placeholder.
