# WebPic Milestone 1 — App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a runnable native macOS SwiftUI app — Swift Package that builds into `WebPic.app`, with the sidebar, toolbar, theme system (light/dark + tokens), and the empty/import screen — matching the reference chrome, with mock data driving the sidebar.

**Architecture:** Swift Package (`WebPicCore` logic library + `WebPicApp` executable). A single `@Observable AppStore` holds UI state mirroring the reference `DCLogic`; a `ThemeManager` handles appearance; a `WPPalette` token layer reproduces the exact colors and is injected via the environment. `NavigationSplitView` provides sidebar + detail; `Scripts/bundle.sh` assembles the `.app`.

**Tech Stack:** Swift 6, SwiftUI (macOS 14+), Observation framework, AppKit interop (`NSApplication`), `swift build` + a bundle script.

**Reference:** [`docs/design-reference/WebPic.dc.html`](../../design-reference/WebPic.dc.html). Spec: [`docs/superpowers/specs/2026-07-01-webpic-design.md`](../specs/2026-07-01-webpic-design.md).

**Native deviations from the HTML (native wins, per brief):** use the real macOS window traffic-light controls (do NOT draw the fake dots from the prototype); use the native titlebar/toolbar and `.regularMaterial` rather than hand-rolled frosted `div`s.

---

### Task 0: Swift Package scaffold + runnable `.app`

**Goal:** `swift build` succeeds and `Scripts/bundle.sh` produces a launchable `WebPic.app` showing an empty window.

**Files:**
- Create: `Package.swift`
- Create: `Sources/WebPicCore/WebPicCore.swift`
- Create: `Sources/WebPicApp/WebPicMain.swift`
- Create: `Sources/WebPicApp/RootView.swift`
- Create: `Scripts/bundle.sh`
- Create: `Tests/WebPicCoreTests/SmokeTests.swift`

**Acceptance Criteria:**
- [ ] `swift build` exits 0
- [ ] `swift test` exits 0 (smoke test passes)
- [ ] `bash Scripts/bundle.sh` writes `dist/WebPic.app`; `open dist/WebPic.app` shows a titled window

**Verify:** `swift build && swift test && bash Scripts/bundle.sh && open dist/WebPic.app` → window titled "WebPic" appears

**Steps:**

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebPic",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WebPicCore"),
        .executableTarget(
            name: "WebPicApp",
            dependencies: ["WebPicCore"]
        ),
        .testTarget(
            name: "WebPicCoreTests",
            dependencies: ["WebPicCore"]
        ),
    ]
)
```

- [ ] **Step 2: Minimal core + smoke test**

`Sources/WebPicCore/WebPicCore.swift`:
```swift
public enum WebPicCore {
    public static let version = "2.0"
}
```

`Tests/WebPicCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import WebPicCore

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(WebPicCore.version, "2.0")
    }
}
```

- [ ] **Step 3: App entry point** — `Sources/WebPicApp/WebPicMain.swift`

```swift
import SwiftUI
import AppKit

@main
struct WebPicMain: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }
    var body: some Scene {
        WindowGroup("WebPic") {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
    }
}
```

- [ ] **Step 4: Placeholder RootView** — `Sources/WebPicApp/RootView.swift`

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        Text("WebPic")
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 5: Bundle script** — `Scripts/bundle.sh`

```bash
#!/bin/bash
set -euo pipefail
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/WebPicApp"
APP="dist/WebPic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WebPic"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>WebPic</string>
  <key>CFBundleDisplayName</key><string>WebPic</string>
  <key>CFBundleIdentifier</key><string>com.flogut.webpic</string>
  <key>CFBundleVersion</key><string>2.0</string>
  <key>CFBundleShortVersionString</key><string>2.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>WebPic</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
echo "Built $APP"
```

- [ ] **Step 6: Verify + commit**

```bash
chmod +x Scripts/bundle.sh
swift build && swift test && bash Scripts/bundle.sh && open dist/WebPic.app
git add Package.swift Sources Tests Scripts
git commit -m "feat: scaffold Swift package + bundle script (M1 task 0)"
```
Expected: build/test green, window appears.

---

### Task 1: Color tokens (`WPPalette` + hex init + environment)

**Goal:** Reproduce the reference light/dark palette as a `WPPalette` value injected through the SwiftUI environment.

**Files:**
- Create: `Sources/WebPicCore/Theme/Color+Hex.swift`
- Create: `Sources/WebPicCore/Theme/WPPalette.swift`
- Create: `Sources/WebPicApp/Theme/WPPaletteEnvironment.swift`
- Test: `Tests/WebPicCoreTests/ColorHexTests.swift`

**Acceptance Criteria:**
- [ ] `Color(hex: 0x0A84FF)` yields sRGB (10,132,255)/255 components
- [ ] `WPPalette.light` and `WPPalette.dark` expose every token used by later tasks
- [ ] `swift test` passes

**Verify:** `swift test --filter ColorHexTests` → PASS

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/ColorHexTests.swift`

```swift
import XCTest
import SwiftUI
@testable import WebPicCore

final class ColorHexTests: XCTestCase {
    func testHexComponents() {
        let c = Color(hex: 0x0A84FF)
        let ns = NSColor(c).usingColorSpace(.sRGB)!
        XCTAssertEqual(Double(ns.redComponent),   10.0/255,  accuracy: 0.01)
        XCTAssertEqual(Double(ns.greenComponent), 132.0/255, accuracy: 0.01)
        XCTAssertEqual(Double(ns.blueComponent),  255.0/255, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL** (`Color(hex:)` undefined)

Run: `swift test --filter ColorHexTests` → Expected: FAIL (no `init(hex:)`)

- [ ] **Step 3: Implement hex init** — `Sources/WebPicCore/Theme/Color+Hex.swift`

```swift
import SwiftUI

public extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
```

- [ ] **Step 4: Implement palette** — `Sources/WebPicCore/Theme/WPPalette.swift`

```swift
import SwiftUI

public struct WPPalette: Sendable {
    public let accent, accentHover, accentPress, accentTint, accentTint2: Color
    public let window, grouped, card: Color
    public let t1, t2, t3, sep, sep2: Color
    public let ctrl, ctrlBorder, seg, segSel, hover, field: Color
    public let statusDone, statusProc, statusWait, statusError: Color

    public static let light = WPPalette(
        accent: Color(hex: 0x0A84FF), accentHover: Color(hex: 0x2A94FF),
        accentPress: Color(hex: 0x0069D0), accentTint: Color(hex: 0xE8F1FE),
        accentTint2: Color(hex: 0xD6E7FD),
        window: Color(hex: 0xFFFFFF), grouped: Color(hex: 0xF1F1F4), card: Color(hex: 0xFFFFFF),
        t1: Color(hex: 0x1D1D1F), t2: Color(hex: 0x605F65), t3: Color(hex: 0x8E8E93),
        sep: Color(hex: 0x000000, alpha: 0.09), sep2: Color(hex: 0x000000, alpha: 0.14),
        ctrl: Color(hex: 0xFFFFFF), ctrlBorder: Color(hex: 0x000000, alpha: 0.13),
        seg: Color(hex: 0xE7E7EA), segSel: Color(hex: 0xFFFFFF),
        hover: Color(hex: 0x000000, alpha: 0.045), field: Color(hex: 0xFFFFFF),
        statusDone: Color(hex: 0x1E9E5A), statusProc: Color(hex: 0x0A84FF),
        statusWait: Color(hex: 0x8E8E93), statusError: Color(hex: 0xE5484D)
    )

    public static let dark = WPPalette(
        accent: Color(hex: 0x0A84FF), accentHover: Color(hex: 0x3A9CFF),
        accentPress: Color(hex: 0x0A6FD0), accentTint: Color(hex: 0x0A84FF, alpha: 0.20),
        accentTint2: Color(hex: 0x0A84FF, alpha: 0.30),
        window: Color(hex: 0x1E1E1F), grouped: Color(hex: 0x161617), card: Color(hex: 0x2A2A2C),
        t1: Color(hex: 0xF5F5F7), t2: Color(hex: 0xA6A6AC), t3: Color(hex: 0x6E6E76),
        sep: Color(hex: 0xFFFFFF, alpha: 0.09), sep2: Color(hex: 0xFFFFFF, alpha: 0.15),
        ctrl: Color(hex: 0x3A3A3D), ctrlBorder: Color(hex: 0xFFFFFF, alpha: 0.14),
        seg: Color(hex: 0x3A3A3D), segSel: Color(hex: 0x636367),
        hover: Color(hex: 0xFFFFFF, alpha: 0.06), field: Color(hex: 0x1B1B1D),
        statusDone: Color(hex: 0x30D158), statusProc: Color(hex: 0x0A84FF),
        statusWait: Color(hex: 0x98989F), statusError: Color(hex: 0xFF453A)
    )
}
```

- [ ] **Step 5: Environment key** — `Sources/WebPicApp/Theme/WPPaletteEnvironment.swift`

```swift
import SwiftUI
import WebPicCore

private struct WPPaletteKey: EnvironmentKey {
    static let defaultValue: WPPalette = .light
}

extension EnvironmentValues {
    var wpPalette: WPPalette {
        get { self[WPPaletteKey.self] }
        set { self[WPPaletteKey.self] = newValue }
    }
}
```

- [ ] **Step 6: Verify + commit**

```bash
swift test --filter ColorHexTests
git add Sources/WebPicCore/Theme Sources/WebPicApp/Theme Tests/WebPicCoreTests/ColorHexTests.swift
git commit -m "feat: color tokens (WPPalette) + hex init (M1 task 1)"
```

---

### Task 2: ThemeManager (system + manual override, persisted)

**Goal:** An `@Observable ThemeManager` that defaults to system appearance, allows a manual Hell/Dunkel override, persists the choice, and maps to a `ColorScheme?`.

**Files:**
- Create: `Sources/WebPicCore/Theme/ThemeManager.swift`
- Test: `Tests/WebPicCoreTests/ThemeManagerTests.swift`

**Acceptance Criteria:**
- [ ] Default appearance is `.system`
- [ ] Setting `.dark` persists and is restored from the same `UserDefaults`
- [ ] `preferredColorScheme` is `nil` for `.system`, `.light`/`.dark` otherwise

**Verify:** `swift test --filter ThemeManagerTests` → PASS

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/ThemeManagerTests.swift`

```swift
import XCTest
import SwiftUI
@testable import WebPicCore

final class ThemeManagerTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "wp.tests.\(UUID().uuidString)")!
        return d
    }

    func testDefaultIsSystem() {
        let tm = ThemeManager(defaults: makeDefaults())
        XCTAssertEqual(tm.appearance, .system)
        XCTAssertNil(tm.preferredColorScheme)
    }

    func testPersistsAndRestores() {
        let d = makeDefaults()
        let tm = ThemeManager(defaults: d)
        tm.appearance = .dark
        let restored = ThemeManager(defaults: d)
        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertEqual(restored.preferredColorScheme, .dark)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL** (`ThemeManager` undefined)

Run: `swift test --filter ThemeManagerTests` → Expected: FAIL

- [ ] **Step 3: Implement** — `Sources/WebPicCore/Theme/ThemeManager.swift`

```swift
import SwiftUI
import Observation

@Observable
public final class ThemeManager {
    public enum Appearance: String, CaseIterable, Sendable {
        case system, light, dark
    }

    public static let storageKey = "wp.appearance"

    @ObservationIgnored private let defaults: UserDefaults

    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.storageKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        self.appearance = Appearance(rawValue: raw) ?? .system
    }

    public var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
```

- [ ] **Step 4: Run test — expect PASS**

Run: `swift test --filter ThemeManagerTests` → Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/WebPicCore/Theme/ThemeManager.swift Tests/WebPicCoreTests/ThemeManagerTests.swift
git commit -m "feat: ThemeManager with persisted appearance (M1 task 2)"
```

---

### Task 3: Domain models + Settings (Codable)

**Goal:** Value-type domain model mirroring the reference state, with `Settings` Codable + preset defaults.

**Files:**
- Create: `Sources/WebPicCore/Models/Enums.swift`
- Create: `Sources/WebPicCore/Models/Preset.swift`
- Create: `Sources/WebPicCore/Models/Settings.swift`
- Create: `Sources/WebPicCore/Models/WebPicImage.swift`
- Test: `Tests/WebPicCoreTests/SettingsTests.swift`

**Acceptance Criteria:**
- [ ] `Settings` round-trips through `JSONEncoder`/`JSONDecoder` unchanged
- [ ] `Preset.all` contains hero/content/thumb/icon/custom with widths 1920/1200/400/256/1600 and default qualities 80/72/65/90/78
- [ ] Default `Settings` matches the reference initial state (single, hero, webp+jpeg, quality mode, quality 78)

**Verify:** `swift test --filter SettingsTests` → PASS

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/SettingsTests.swift`

```swift
import XCTest
@testable import WebPicCore

final class SettingsTests: XCTestCase {
    func testCodableRoundTrip() throws {
        var s = Settings.default
        s.compression = .target(value: 200, unit: .kb)
        s.formats = [.webp, .avif]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testPresetTable() {
        let hero = Preset.all.first { $0.key == .hero }!
        XCTAssertEqual(hero.width, 1920)
        XCTAssertEqual(hero.defaultQuality, 80)
        XCTAssertEqual(Preset.all.map(\.key),
                       [.hero, .content, .thumb, .icon, .custom])
    }

    func testDefaults() {
        let s = Settings.default
        XCTAssertEqual(s.outputMode, .single)
        XCTAssertEqual(s.preset, .hero)
        XCTAssertEqual(s.formats, [.webp, .jpeg])
        XCTAssertEqual(s.compression, .quality(78))
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter SettingsTests` → Expected: FAIL (types undefined)

- [ ] **Step 3: Enums** — `Sources/WebPicCore/Models/Enums.swift`

```swift
import Foundation

public enum Tab: String, Codable, Sendable { case batch, settings, compare, export }
public enum OutputMode: String, Codable, CaseIterable, Sendable { case single, responsive, convert }
public enum ImageFormat: String, Codable, CaseIterable, Sendable { case webp, avif, jpeg, png }
public enum SizeUnit: String, Codable, Sendable { case kb, mb }
public enum ColorSpace: String, Codable, Sendable { case sRGB, displayP3 }

public enum Compression: Codable, Equatable, Sendable {
    case quality(Int)
    case target(value: Double, unit: SizeUnit)
}
```

- [ ] **Step 4: Preset** — `Sources/WebPicCore/Models/Preset.swift`

```swift
import Foundation

public struct Preset: Equatable, Sendable, Identifiable {
    public enum Key: String, Codable, CaseIterable, Sendable {
        case hero, content, thumb, icon, custom
    }
    public let key: Key
    public let label: String
    public let sub: String
    public let width: Int
    public let defaultQuality: Int
    public var id: Key { key }

    public static let all: [Preset] = [
        Preset(key: .hero,    label: "Hero-Image",   sub: "1920w", width: 1920, defaultQuality: 80),
        Preset(key: .content, label: "Content-Bild", sub: "1200w", width: 1200, defaultQuality: 72),
        Preset(key: .thumb,   label: "Thumbnail",    sub: "400w",  width: 400,  defaultQuality: 65),
        Preset(key: .icon,    label: "Icon / Avatar",sub: "256w",  width: 256,  defaultQuality: 90),
        Preset(key: .custom,  label: "Custom",       sub: "frei",  width: 1600, defaultQuality: 78),
    ]

    public static func width(for key: Key) -> Int { all.first { $0.key == key }!.width }
    public static func defaultQuality(for key: Key) -> Int { all.first { $0.key == key }!.defaultQuality }
}
```

- [ ] **Step 5: Settings** — `Sources/WebPicCore/Models/Settings.swift`

```swift
import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var outputMode: OutputMode
    public var preset: Preset.Key
    public var formats: Set<ImageFormat>
    public var compression: Compression
    public var breakpoints: Set<Int>
    public var customBreakpoint: Int?
    public var colorSpace: ColorSpace
    public var keepMetadata: Bool
    public var filenameScheme: String

    public static let `default` = Settings(
        outputMode: .single,
        preset: .hero,
        formats: [.webp, .jpeg],
        compression: .quality(78),
        breakpoints: [400, 800, 1200],
        customBreakpoint: nil,
        colorSpace: .sRGB,
        keepMetadata: false,
        filenameScheme: "{name}-{w}.{format}"
    )
}
```

- [ ] **Step 6: WebPicImage** — `Sources/WebPicCore/Models/WebPicImage.swift`

```swift
import Foundation

public enum ImageStatus: Equatable, Sendable {
    case waiting
    case processing(Double)   // 0...1
    case done
    case error(String)
}

public struct WebPicImage: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var byteSize: Int
    public var status: ImageStatus
    public var url: URL?
    /// Mock gradient key used until real thumbnails exist (M2). Hex pair.
    public var gradient: [UInt32]

    public init(id: String, name: String, pixelWidth: Int, pixelHeight: Int,
                byteSize: Int, status: ImageStatus, url: URL? = nil,
                gradient: [UInt32] = [0x5AC8FA, 0x0A84FF]) {
        self.id = id; self.name = name
        self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.byteSize = byteSize; self.status = status
        self.url = url; self.gradient = gradient
    }
}
```

- [ ] **Step 7: Run test — expect PASS**, then commit

```bash
swift test --filter SettingsTests
git add Sources/WebPicCore/Models Tests/WebPicCoreTests/SettingsTests.swift
git commit -m "feat: domain models + Settings Codable (M1 task 3)"
```

---

### Task 4: AppStore (`@Observable`) + reducers

**Goal:** The single source of UI truth, mirroring the reference `DCLogic`, with mock-seed import and selection/removal logic (real file import lands in M2).

**Files:**
- Create: `Sources/WebPicCore/AppStore.swift`
- Create: `Sources/WebPicCore/MockData.swift`
- Create: `Sources/WebPicCore/Formatting.swift`
- Test: `Tests/WebPicCoreTests/AppStoreTests.swift`

**Acceptance Criteria:**
- [ ] `addImages()` on an empty store seeds 4 mock images, selects the first, tab → `.settings`
- [ ] `select(id:)` while on `.batch` switches tab to `.settings`; on other tabs keeps the tab
- [ ] `remove(id:)` drops the image and reselects the first remaining (or nil when empty)
- [ ] `formatBytes` renders `6083000 → "6,1 MB"`, `430000 → "420 KB"` (German comma decimal)

**Verify:** `swift test --filter AppStoreTests` → PASS

**Steps:**

- [ ] **Step 1: Failing test** — `Tests/WebPicCoreTests/AppStoreTests.swift`

```swift
import XCTest
@testable import WebPicCore

final class AppStoreTests: XCTestCase {
    func testAddSeedsAndSelects() {
        let s = AppStore(defaults: Self.tmpDefaults())
        s.addImages()
        XCTAssertEqual(s.images.count, 4)
        XCTAssertEqual(s.selectedID, s.images.first?.id)
        XCTAssertEqual(s.tab, .settings)
    }

    func testSelectFromBatchGoesToSettings() {
        let s = AppStore(defaults: Self.tmpDefaults())
        s.addImages()
        s.tab = .batch
        s.select(id: s.images[2].id)
        XCTAssertEqual(s.selectedID, s.images[2].id)
        XCTAssertEqual(s.tab, .settings)
    }

    func testRemoveReselects() {
        let s = AppStore(defaults: Self.tmpDefaults())
        s.addImages()
        let firstID = s.images[0].id
        s.remove(id: firstID)
        XCTAssertEqual(s.images.count, 3)
        XCTAssertEqual(s.selectedID, s.images.first?.id)
        XCTAssertNotEqual(s.selectedID, firstID)
    }

    func testFormatBytes() {
        XCTAssertEqual(formatBytes(6_083_000), "6,1 MB")
        XCTAssertEqual(formatBytes(430_000), "420 KB")
        XCTAssertEqual(formatBytes(512), "512 B")
    }

    private static func tmpDefaults() -> UserDefaults {
        UserDefaults(suiteName: "wp.tests.\(UUID().uuidString)")!
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter AppStoreTests` → Expected: FAIL

- [ ] **Step 3: Formatting helper** — `Sources/WebPicCore/Formatting.swift`

```swift
import Foundation

/// Mirrors the reference `fmt()`: B / KB (0 decimals) / MB (1 decimal, comma).
public func formatBytes(_ b: Int) -> String {
    if b < 1000 { return "\(b) B" }
    if b < 1024 * 1024 { return "\(Int((Double(b) / 1024).rounded())) KB" }
    let mb = (Double(b) / 1_048_576)
    return String(format: "%.1f", mb).replacingOccurrences(of: ".", with: ",") + " MB"
}
```

- [ ] **Step 4: Mock data** — `Sources/WebPicCore/MockData.swift`

```swift
import Foundation

public enum MockData {
    public static func seedImages() -> [WebPicImage] {
        [
            WebPicImage(id: "i1", name: "hero-banner.jpg",  pixelWidth: 4032, pixelHeight: 2268,
                        byteSize: 6_083_000, status: .done,           gradient: [0x5AC8FA, 0x0A84FF]),
            WebPicImage(id: "i2", name: "team-photo.jpg",   pixelWidth: 3000, pixelHeight: 2000,
                        byteSize: 4_300_000, status: .processing(0.62), gradient: [0xFF9F45, 0xFF6B6B]),
            WebPicImage(id: "i3", name: "product-shot.png", pixelWidth: 2400, pixelHeight: 2400,
                        byteSize: 6_500_000, status: .waiting,        gradient: [0x30D158, 0x0A84FF]),
            WebPicImage(id: "i4", name: "avatar-jane.png",  pixelWidth: 512,  pixelHeight: 512,
                        byteSize: 430_000,  status: .error("Konnte nicht dekodiert werden"),
                        gradient: [0xB0B0B8, 0x7C7C86]),
        ]
    }
}
```

- [ ] **Step 5: AppStore** — `Sources/WebPicCore/AppStore.swift`

```swift
import Foundation
import Observation

@Observable
public final class AppStore {
    public var images: [WebPicImage] = []
    public var selectedID: String?
    public var tab: Tab = .settings
    public var settings: Settings
    public var sheet: SheetKind? = nil
    public var framework: SnippetFramework = .html
    public var lazyLoading: Bool = true
    public var showUpdate: Bool = true

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

    public func addImages() {
        if images.isEmpty {
            images = MockData.seedImages()
            selectedID = images.first?.id
            tab = .settings
        } else {
            tab = .batch
        }
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

    public func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }
}
```

- [ ] **Step 6: Run test — expect PASS**, then commit

```bash
swift test --filter AppStoreTests
git add Sources/WebPicCore/AppStore.swift Sources/WebPicCore/MockData.swift Sources/WebPicCore/Formatting.swift Tests/WebPicCoreTests/AppStoreTests.swift
git commit -m "feat: AppStore + mock seed + byte formatting (M1 task 4)"
```

---

### Task 5: Sidebar view

**Goal:** Build the sidebar exactly per reference: logo + title + version, "Bilder hinzufügen" primary button, "Alle Bilder" batch row with count, scrollable image list (thumbnail gradient, name, `w×h · size`, status dot, remove ×), update pill (conditional), Hell/Dunkel segmented.

**Files:**
- Create: `Sources/WebPicApp/Sidebar/SidebarView.swift`
- Create: `Sources/WebPicApp/Sidebar/ImageRow.swift`
- Create: `Sources/WebPicApp/Shared/GradientSwatch.swift`
- Create: `Sources/WebPicApp/Shared/StatusColor.swift`

**Acceptance Criteria:**
- [ ] Sidebar shows title "WebPic" + version "2.0", primary add button, "Alle Bilder" row with the image count
- [ ] Each image row shows gradient thumb, name, `w×h · size` (monospaced digits), status dot color per status, and a hover-revealed remove ×
- [ ] Update pill appears only when `store.showUpdate`; tapping it sets `sheet = .update`
- [ ] Hell/Dunkel segmented reflects and sets `theme.appearance`

**Verify:** builds via `swift build`; visually confirmed in Task 6 screenshot.

**Steps:**

- [ ] **Step 1: Status color helper** — `Sources/WebPicApp/Shared/StatusColor.swift`

```swift
import SwiftUI
import WebPicCore

func statusColor(_ status: ImageStatus, _ p: WPPalette) -> Color {
    switch status {
    case .done:       return p.statusDone
    case .processing: return p.statusProc
    case .waiting:    return p.statusWait
    case .error:      return p.statusError
    }
}
```

- [ ] **Step 2: Gradient swatch** — `Sources/WebPicApp/Shared/GradientSwatch.swift`

```swift
import SwiftUI
import WebPicCore

struct GradientSwatch: View {
    let hexes: [UInt32]
    var cornerRadius: CGFloat = 7
    var body: some View {
        LinearGradient(
            colors: hexes.map { Color(hex: $0) },
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
```

- [ ] **Step 3: Image row** — `Sources/WebPicApp/Sidebar/ImageRow.swift`

```swift
import SwiftUI
import WebPicCore

struct ImageRow: View {
    @Environment(\.wpPalette) private var p
    let image: WebPicImage
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                GradientSwatch(hexes: image.gradient)
                    .frame(width: 34, height: 34)
                    .overlay {
                        if case .processing = image.status {
                            ProgressView().controlSize(.small).tint(.white)
                        } else if case .error = image.status {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.white).font(.system(size: 13, weight: .bold))
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(image.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? p.accent : p.t1)
                        .lineLimit(1).truncationMode(.tail)
                    Text("\(image.pixelWidth)×\(image.pixelHeight) · \(formatBytes(image.byteSize))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(p.t3)
                }
                Spacer(minLength: 4)
                Circle().fill(statusColor(image.status, p)).frame(width: 8, height: 8)
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain).foregroundStyle(p.t3)
                    .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 7).padding(.horizontal, 9)
            .background(isSelected ? p.accentTint : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
```

- [ ] **Step 4: Sidebar** — `Sources/WebPicApp/Sidebar/SidebarView.swift`

```swift
import SwiftUI
import WebPicCore

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeManager.self) private var theme
    @Environment(\.wpPalette) private var p

    var body: some View {
        VStack(spacing: 0) {
            // Header: logo + title + version
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [p.accent, Color(hex: 0x5AC8FA)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .overlay { Image(systemName: "photo").foregroundStyle(.white).font(.system(size: 12, weight: .semibold)) }
                Text("WebPic").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(WebPicCore.version).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)

            // Add images
            Button { store.addImages() } label: {
                Label("Bilder hinzufügen", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity).frame(height: 32)
            }
            .buttonStyle(.borderedProminent).tint(p.accent)
            .padding(.horizontal, 14).padding(.bottom, 12)

            // Alle Bilder (batch)
            Button { store.tab = .batch } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                    Text("Alle Bilder").frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(store.images.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(p.seg, in: Capsule()).foregroundStyle(p.t2)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(store.tab == .batch ? p.accent : p.t1)
                .padding(.vertical, 7).padding(.horizontal, 12)
                .background(store.tab == .batch ? p.accentTint : .clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.horizontal, 10)

            // Section header
            Text("BILDER")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(p.t3)
                .kerning(0.4).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 6)

            // Image list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.images) { img in
                        ImageRow(image: img,
                                 isSelected: img.id == store.selectedID && store.tab != .batch,
                                 onSelect: { store.select(id: img.id) },
                                 onRemove: { store.remove(id: img.id) })
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 10)
            }

            Divider()

            // Footer: update pill + theme toggle
            VStack(spacing: 9) {
                if store.showUpdate {
                    Button { store.sheet = .update } label: {
                        HStack(spacing: 8) {
                            Circle().fill(p.accent).frame(width: 7, height: 7)
                            Text("Update 2.1 verfügbar")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(p.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(p.accent)
                        }
                        .padding(.vertical, 7).padding(.horizontal, 9)
                        .background(p.accentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Image(systemName: "sun.max").font(.system(size: 13)).foregroundStyle(p.t2)
                    Picker("", selection: Binding(
                        get: { theme.appearance == .dark ? 1 : 0 },
                        set: { theme.appearance = $0 == 1 ? .dark : .light })) {
                        Text("Hell").tag(0)
                        Text("Dunkel").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }
}
```

- [ ] **Step 5: Build + commit**

```bash
swift build
git add Sources/WebPicApp/Sidebar Sources/WebPicApp/Shared
git commit -m "feat: sidebar view + image rows (M1 task 5)"
```

---

### Task 6: Toolbar + main routing + empty state + RootView wiring (build & screenshot)

**Goal:** Wire `NavigationSplitView`, the toolbar (title/subtitle, `Einstellungen | Vergleich` segmented, code + Exportieren buttons), and the empty/import screen; inject `AppStore` + `ThemeManager` + palette; verify by building the `.app` and screenshotting empty and populated states in both light and dark.

**Files:**
- Modify: `Sources/WebPicApp/RootView.swift`
- Create: `Sources/WebPicApp/MainView.swift`
- Create: `Sources/WebPicApp/Import/EmptyImportView.swift`
- Create: `Sources/WebPicApp/Settings/SettingsPlaceholderView.swift`
- Modify: `Sources/WebPicApp/WebPicMain.swift`

**Acceptance Criteria:**
- [ ] Launch shows the empty/import screen with drop-zone card + "Bilder auswählen …" / "Aus Fotos importieren"
- [ ] Clicking either import button seeds mock images and switches to the settings placeholder; sidebar populates
- [ ] Toolbar shows the selected image name/subtitle + `Einstellungen | Vergleich` segmented + code button + Exportieren button (non-empty, non-batch)
- [ ] Hell/Dunkel toggle recolors the whole window; empty and populated states screenshot correctly in both modes

**Verify:** `bash Scripts/bundle.sh && open dist/WebPic.app` → screenshot empty + populated in light + dark, compared to reference.

**Steps:**

- [ ] **Step 1: Empty/import screen** — `Sources/WebPicApp/Import/EmptyImportView.swift`

```swift
import SwiftUI
import WebPicCore

struct EmptyImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.wpPalette) private var p

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(p.accentTint).frame(width: 72, height: 72)
                    .overlay { Image(systemName: "photo").font(.system(size: 30, weight: .light)).foregroundStyle(p.accent) }
                    .padding(.bottom, 22)
                Text("Bilder für das Web optimieren")
                    .font(.system(size: 22, weight: .bold))
                Text("Zieh Bilder aus Fotos oder dem Finder hierher – oder wähle sie manuell aus. WebP, AVIF & responsive Größen in Sekunden.")
                    .font(.system(size: 14)).foregroundStyle(p.t2)
                    .multilineTextAlignment(.center).lineSpacing(2)
                    .frame(maxWidth: 400).padding(.top, 8).padding(.bottom, 26)
                HStack(spacing: 10) {
                    Button("Bilder auswählen …") { store.addImages() }
                        .buttonStyle(.borderedProminent).tint(p.accent).controlSize(.large)
                    Button("Aus Fotos importieren") { store.addImages() }
                        .buttonStyle(.bordered).controlSize(.large)
                }
            }
            .padding(.vertical, 56).padding(.horizontal, 40)
            .frame(maxWidth: 560)
            .background(p.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(p.sep2, style: StrokeStyle(lineWidth: 2, dash: [6]))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
        .background(p.grouped)
    }
}
```

- [ ] **Step 2: Settings placeholder** — `Sources/WebPicApp/Settings/SettingsPlaceholderView.swift`

```swift
import SwiftUI
import WebPicCore

struct SettingsPlaceholderView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.wpPalette) private var p
    var body: some View {
        VStack(spacing: 8) {
            Text(store.selected?.name ?? "—").font(.system(size: 17, weight: .semibold))
            Text("Einstellungen folgen in Meilenstein 3").foregroundStyle(p.t3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.grouped)
    }
}
```

- [ ] **Step 3: MainView (routing + toolbar)** — `Sources/WebPicApp/MainView.swift`

```swift
import SwiftUI
import WebPicCore

struct MainView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.wpPalette) private var p

    var body: some View {
        Group {
            if store.isEmpty {
                EmptyImportView()
            } else if store.tab == .batch {
                SettingsPlaceholderView()   // real Batch grid = M7
            } else {
                SettingsPlaceholderView()   // real Settings/Compare = M3/M5
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle("")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !store.isEmpty {
            ToolbarItem(placement: .navigation) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.tab == .batch ? "Alle Bilder" : (store.selected?.name ?? "WebPic"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
                }
            }
            if store.tab != .batch {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: Binding(
                        get: { store.tab == .compare ? 1 : 0 },
                        set: { store.tab = $0 == 1 ? .compare : .settings })) {
                        Text("Einstellungen").tag(0)
                        Text("Vergleich").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { store.sheet = .code } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                    Button { store.tab = .export } label: {
                        Label("Exportieren", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent).tint(p.accent)
                }
            }
        }
    }

    private var subtitle: String {
        if store.tab == .batch { return "\(store.images.count) Bilder" }
        guard let im = store.selected else { return "Bereit zum Import" }
        return "\(im.pixelWidth)×\(im.pixelHeight) · \(formatBytes(im.byteSize))"
    }
}
```

- [ ] **Step 4: RootView** — replace `Sources/WebPicApp/RootView.swift`

```swift
import SwiftUI
import WebPicCore

struct RootView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.colorScheme) private var systemScheme

    private var effectiveScheme: ColorScheme {
        switch theme.appearance {
        case .system: return systemScheme
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    private var palette: WPPalette { effectiveScheme == .dark ? .dark : .light }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(250)
        } detail: {
            MainView()
        }
        .environment(\.wpPalette, palette)
        .preferredColorScheme(theme.preferredColorScheme)
        .tint(.blue)
    }
}
```

- [ ] **Step 5: Inject stores** — replace body of `Sources/WebPicApp/WebPicMain.swift`

```swift
import SwiftUI
import WebPicCore

@main
struct WebPicMain: App {
    @State private var store = AppStore()
    @State private var theme = ThemeManager()

    init() { NSApplication.shared.setActivationPolicy(.regular) }

    var body: some Scene {
        WindowGroup("WebPic") {
            RootView()
                .environment(store)
                .environment(theme)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
    }
}
```
Add `import AppKit` at top if `NSApplication` is unresolved.

- [ ] **Step 6: Build, bundle, screenshot, commit**

```bash
swift build && bash Scripts/bundle.sh && open dist/WebPic.app
# screenshot empty state, click import, screenshot populated; toggle Dunkel, repeat
git add Sources/WebPicApp
git commit -m "feat: toolbar + routing + empty state + root wiring (M1 task 6)"
```
Expected: empty → import → populated works; light/dark both correct against the reference.

---

## Milestone 1 acceptance

- [ ] `swift build` and `swift test` green
- [ ] `WebPic.app` launches; empty/import → mock import → sidebar + toolbar populated
- [ ] Sidebar matches reference (logo/title/version, add button, Alle Bilder + count, image rows w/ status dots + remove, update pill, Hell/Dunkel)
- [ ] Light and dark both render with the exact token palette
- [ ] Every M1 file committed

## Notes for later milestones (not in scope here)
- M2 replaces `AppStore.addImages()` mock seed with real Finder drag&drop + `NSOpenPanel` + PhotosUI import and real thumbnails.
- `SettingsPlaceholderView` is throwaway — replaced by the full Settings screen in M3 and Compare in M5.
- C targets (`CWebP`, `CAVIF`) are added in M4, not now.
