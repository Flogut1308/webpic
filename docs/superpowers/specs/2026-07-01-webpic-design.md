# WebPic — Design Spec

**Date:** 2026-07-01
**Status:** Approved (design phase)
**Reference:** [`docs/design-reference/WebPic.dc.html`](../../design-reference/WebPic.dc.html) — the binding interactive prototype (look, flow, states, copy). Original brief: [`docs/design-reference/Claude-Code-Prompt.md`](../../design-reference/Claude-Code-Prompt.md).

## 1. Overview

WebPic is a native macOS app for optimizing images for the web: convert, compress, resize, generate responsive sets, and produce copy-paste `<picture>` / React / Next.js / Vue snippets. It is distributed as a downloadable, self-contained app (DMG/ZIP) — not via the App Store.

The reference `WebPic.dc.html` defines the UI verbatim. This spec re-implements it **natively** in SwiftUI; where a native control differs slightly from the HTML custom control, the native variant wins.

## 2. Goals / Non-goals

**Goals**
- High-fidelity native reproduction of every screen, state, token, and copy string in the reference.
- Real image optimization that produces genuinely smaller files; target-file-size mode that hits the target.
- Copy-paste-correct code snippets for all four frameworks.
- Light/dark with system appearance + manual override.
- Auto-update via GitHub Releases.

**Non-goals (YAGNI)**
- No web wrapper (Electron/Tauri) — native feel is the core requirement.
- No App Store distribution.
- No cloud/account features. No image editing beyond resize/convert/compress.
- Localization beyond German for v1 (strings centralized to allow it later).

## 3. Resolved decisions

| Topic | Decision |
|---|---|
| Tech | SwiftUI, macOS 14+, AppKit interop where needed |
| Project format | Swift Package (`Package.swift`), no committed `.xcodeproj`; `Scripts/bundle.sh` assembles the `.app` |
| Repo | `github.com/Flogut1308/webpic` (private) |
| WebP/AVIF encoding | In-process C libs: **libwebp** + **libavif** (SPM C targets), behind a pluggable `ImageEncoder` protocol |
| JPEG/PNG/HEIC | Native ImageIO (`CGImageDestination`) |
| Build/verify | Full Xcode on this Mac; build + run + screenshot each milestone. Free Apple ID (local ad-hoc signing) sufficient for development |
| Notarization / paid Apple Developer account | **Deferred to Milestone 8**; decide then (notarize vs. unsigned + documented "right-click → Open") |
| UI language | German only (strings centralized) |
| Deployment | macOS 14+; window resizable (reference 1360×864 is a reference size, not a fixed frame) |
| Persistence | `Settings` + theme persisted via `UserDefaults`; image list is per-session (re-import on relaunch) |
| Export destinations | Folder (`NSSavePanel`) + Photos framework + `NSSharingServicePicker` |
| Auto-update | Sparkle 2 (SPM), GitHub-Releases appcast, EdDSA-signed |

## 4. Architecture

Single `@Observable` **AppStore** as source of truth; value-type models; services behind protocols. `NavigationSplitView` (sidebar + detail), `.toolbar` titlebar, native `Picker(.segmented)` / `Slider` / `Toggle` / `.sheet`, SF Symbols, `.regularMaterial` frosted sidebar/toolbar, `.tint(.blue)`.

The AppStore mirrors the reference `DCLogic` state: `images`, `selectedID`, `tab` (`batch|settings|compare|export`), `outputMode` (`single|responsive|convert`), `preset`, `formats`, `compMode` (`quality|target`), `quality`, `target{value,unit}`, `breakpoints`, `sameForAll`, advanced (`keepMeta`, `colorSpace`, `filenameScheme`), `theme`, `sheet` (`code|update|nil`), `framework`, `lazy`, `exportState` (`idle|busy|done`), `showUpdate`, `updating`.

### Package layout
```
Package.swift
Sources/
  CWebP/         # libwebp (SPM C target)
  CAVIF/         # libavif + aom (SPM C target)
  WebPicCore/    # models, AppStore, services (pure, unit-tested)
  WebPicApp/     # @main App + SwiftUI views
    Import/  Settings/  Compare/  Export/  Batch/  Update/  Shared/
Tests/WebPicCoreTests/
Scripts/bundle.sh   # assemble WebPic.app (Info.plist, icon, entitlements)
```
`swift build` produces the executable; `bundle.sh` wraps it into a proper `.app` (needed for GUI activation policy and, later, Sparkle + signing).

## 5. Models (value types)

- **`WebPicImage`** — `id`, `url`, `name`, `pixelSize (w,h)`, `byteSize`, `status: .waiting | .processing(Double) | .done | .error(String)`, `thumbnail`, decoded source handle, optional per-image `Settings` override (when not `sameForAll`), `results: [EncodeResult]`.
- **`Settings`** (Codable, persisted) — `outputMode`, `preset`, `formats: Set<ImageFormat>`, `compression: .quality(Int) | .target(value: Double, unit: .kb|.mb)`, `breakpoints: Set<Int>`, `customBreakpoint: Int?`, `colorSpace: .sRGB|.displayP3`, `keepMetadata: Bool`, `filenameScheme: String` (default `{name}-{w}.{format}`).
- **`Preset`** — `key`, `label`, `width`, `defaultQuality`. Values: Hero 1920w/80, Content 1200w/72, Thumbnail 400w/65, Icon 256w/90, Custom (free)/78.
- **`ImageFormat`** — `webp, avif, jpeg, png` (+ HEIC internally). `type` attr + extension mapping for snippets.
- **`EncodeResult`** — `format`, `width`, `byteSize`, `data`/`url`, `chosenQuality` (for target mode note).

## 6. Services

### ImageProcessor (actor)
`decode (ImageIO) → resize (vImage / Core Graphics) → encode (ImageEncoder)`. Implementations: `ImageIOEncoder` (JPEG/PNG/HEIC), `WebPEncoder` (libwebp), `AVIFEncoder` (libavif).
- **Target size:** binary search over the encoder quality parameter until output is just under target; feasibility floor mirrors the reference (`orig · areaFactor · formatFactor · 0.10`). Records `chosenQuality`.
- **Metadata/ICC:** preserve or strip via ImageIO properties; sRGB ↔ Display P3 conversion.
- **Concurrency:** `TaskGroup`; per-image progress callbacks feed `WebPicImage.status`.

### EstimationService
Instant heuristic estimate for live slider feedback (reference factor model: AVIF 0.30 / WebP 0.44 / JPEG 0.64 / PNG 0.9; `q = 0.14 + quality/100 · 0.86`; `areaFactor = (min(presetW, origW)/origW)²`). Real numbers from an actual encode replace the estimate on Compare/Export. Rationale: a real encode per slider tick would stutter; heuristic keeps the slider responsive.

### SnippetGenerator (pure)
`(formats, breakpoints, dims, filenameScheme, framework, lazy) → String`. Ports the reference `buildCode` logic for HTML/React/Next/Vue and extends it with real `srcset`/`sizes` for Responsive Set output. Correct `type="image/…"`, `loading="lazy"`, `decoding="async"`. Fallback format = PNG if selected else JPEG. Source order: AVIF then WebP.

### ExportService
`NSSavePanel` folder write · Photos framework save · `NSSharingServicePicker`.

### Updater
Sparkle 2 (SPM) + GitHub-Releases-hosted appcast (EdDSA-signed). Drives the sidebar update banner and the update modal (version, changelog, install w/ loading). Fallback: lightweight GitHub Releases API checker + DMG/ZIP download.

## 7. Theming & tokens

System appearance + manual Hell/Dunkel override via `.preferredColorScheme`. Native `.regularMaterial` for frosted sidebar/toolbar; `.tint(.blue)`. A `WPColor` token layer reproduces the exact palette per mode; `.monospacedDigit()` for all sizes/dims/percentages. Radii: buttons 6–8, cards 12–14, window/sheets 12–16. Sidebar ~250pt, toolbar ~46pt.

Key tokens (from reference; full set in the reference file):
- Accent `#0A84FF` (hover `#2A94FF`, pressed `#0069D0`, tint light `#E8F1FE`).
- Light: window `#FFFFFF`, grouped `#F1F1F4`, card `#FFFFFF`, text `#1D1D1F / #605F65 / #8E8E93`, sep `rgba(0,0,0,0.09)`.
- Dark: window `#1E1E1F`, grouped `#161617`, card `#2A2A2C`, text `#F5F5F7 / #A6A6AC / #6E6E76`.
- Status: done `#30D158`/`#1E9E5A`, processing `#0A84FF`, waiting `#8E8E93`, error `#FF453A`/`#E5484D`.

## 8. Screens & states (binding inventory)

- **Empty/Import** — dashed drop zone, "Bilder auswählen …" / "Aus Fotos importieren". Finder drag&drop + Photos import, multi-select. After import: select first image, switch to Settings.
- **Sidebar** — app title + version, "Bilder hinzufügen", "Alle Bilder" (batch) with count, image rows (thumbnail, `w×h · size`, status dot, remove ×). Bottom: update pill (conditional) + Hell/Dunkel segmented.
- **Toolbar** — thumbnail + title/subtitle, `Einstellungen | Vergleich` segmented, code-snippet button, `Exportieren` button. Hidden appropriately in empty/batch.
- **Settings** — Ausgabe segmented; Preset cards; Format toggles (multi); Komprimierung card (`Qualität ↔ Zieldateigröße`; quality slider + live estimate; target field KB/MB with **error** ("Zu klein – realistisch sind mind. X") and **ok** ("Qualität ≈X%") states); Responsive breakpoints (400/800/1200/1920 + custom) when responsive; Advanced (Metadaten behalten toggle, Farbraum sRGB/P3, Dateinamen-Schema). Sticky live-preview column (Original→Optimiert, savings bar, −%, spart X, dims, format).
- **Compare** — draggable before/after slider over Original/Optimiert; three metric cards (−%, gespart, neue Auflösung).
- **Export/Review** — summary of all settings; target-mode note ("Qualität automatisch auf ≈X% angepasst"); actions **In Fotos speichern** · **Teilen** · **Code-Snippet**. Save button states: idle/busy/done.
- **Code-Snippet sheet** — framework segmented (HTML `<picture>` / React / Next.js / Vue), syntax-highlighted code, Copy button with "Kopiert" feedback, `loading="lazy"` toggle.
- **Batch** — "Alle gleich behandeln" toggle ↔ individual, "Alle entfernen", grid of cards with per-image status (Wartet / Verarbeitet + progress / Fertig / Fehler).
- **Update** — sidebar banner ("Update 2.1 verfügbar") + modal (version, size, changelog, "Später" / "Installieren & neu starten" w/ loading).

**Component states to implement:** buttons (default/pressed/disabled/loading/success); target input (default/focused/filled/error/disabled); toggle (on/off/disabled); slider (default/dragging); chips/presets (default/selected/disabled); image cards (default/selected/processing/done/error).

## 9. Milestones (each buildable + shown)

1. **App shell** — split view, toolbar, theme + tokens, empty/import state.
2. **Import + image model** — Finder drag&drop, file picker, Photos import; sidebar list (thumb/res/size/status/remove).
3. **Settings UI complete** + live estimate (mock encoder) + preview column.
4. **Real encoder pipeline** — ImageIO + libwebp + libavif, resize, metadata/colorspace, target-size binary search; wire real numbers into preview.
5. **Compare + Export/Save** — draggable before/after + metric cards; review screen; folder/Photos/Share.
6. **Code snippets** — the four generators with real responsive `srcset`/`sizes`.
7. **Batch** — grid + concurrent processing + real progress.
8. **Sparkle update + packaging** — `.app`/DMG via `bundle.sh`; notarization decision.

Build after every milestone and show it.

## 10. Testing & verification

- **TDD (pure logic):** SnippetGenerator (exact output per framework/format/responsive), target-size binary-search convergence, filename-scheme expansion, `Settings` Codable round-trip, estimation math.
- **ImageProcessor:** against fixture images — output smaller than input, dimensions correct, format magic-bytes correct, metadata preserved/stripped as configured.
- **Per milestone:** build + launch + screenshot on this Mac, compared against the reference.
- **Acceptance:** screens/flows match the reference; all component states present; light/dark correct; real optimization yields smaller files; target size is hit; snippets are copy-paste-correct; update flow works.

## 11. Deferred / open

- Apple Developer account ($99/yr) for **notarization** — Milestone 8. Until then, local ad-hoc signing (free Apple ID) is enough to build & run. Fallback for distribution: unsigned + documented Gatekeeper bypass.
- App icon asset (placeholder for now; final icon TBD).
- Sparkle EdDSA key generation + appcast hosting details — Milestone 8.
