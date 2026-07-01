# WebPic Milestone 6 — Code Snippets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The Code-Snippet sheet — a pure `SnippetGenerator` producing copy-paste-correct HTML `<picture>` / React / Next.js `<Image>` / Vue markup (with `srcset`/`sizes` for responsive sets, `loading="lazy"` toggle), a lightweight syntax tokenizer, and the sheet UI (framework segmented, highlighted code, copy-with-feedback, lazy toggle).

**Architecture:** `SnippetGenerator` (pure, WebPicCore) ports the reference `buildCode` for single-image output and extends it with responsive `srcset`. `SyntaxHighlighter.tokenize` returns `[CodeToken]` (pure, round-trippable) that the view colors. `CodeSheet` (SwiftUI) overlays when `store.sheet == .code`, driven by `store.framework` / `store.lazyLoading`. `SnippetFramework` is promoted from a nested `AppStore` type to a top-level `WebPicCore` enum.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSPasteboard` for copy).

**Reference:** `buildCode`/`highlight` in `WebPic.dc.html` (~628–675) and the code sheet markup (~452–478). Spec §6 (SnippetGenerator). Builds on M1–M5.

---

### Task 0: SnippetGenerator — single-image (4 frameworks)

**Goal:** Pure generator reproducing the reference output for HTML/React/Next/Vue in single-image mode, with the `loading="lazy"` toggle.

**Files:**
- Create: `Sources/WebPicCore/Snippets/SnippetFramework.swift` (promote enum), `Sources/WebPicCore/Snippets/SnippetGenerator.swift`
- Modify: `Sources/WebPicCore/AppStore.swift` (use top-level `SnippetFramework`; remove nested)
- Test: `Tests/WebPicCoreTests/SnippetGeneratorTests.swift`

**Acceptance Criteria (exact reference output):**
- [ ] HTML with formats [avif, webp] + jpeg fallback, lazy on:
```
<picture>
  <source srcset="/img/hero.avif" type="image/avif">
  <source srcset="/img/hero.webp" type="image/webp">
  <img src="/img/hero.jpg" alt="" width="1200" height="600" loading="lazy" decoding="async">
</picture>
```
- [ ] React uses `srcSet`/`width={1200}`; Next.js emits `import Image from "next/image"` + `<Image …>`; Vue wraps in `<template>`
- [ ] `lazy: false` omits `loading="lazy"`; fallback is `png` when PNG selected else `jpg`; sources are avif then webp (only those selected)

**Verify:** `swift test --filter SnippetGeneratorTests`

**Steps:**

- [ ] **Step 1: Promote `SnippetFramework`** — create `Sources/WebPicCore/Snippets/SnippetFramework.swift`:
```swift
public enum SnippetFramework: String, CaseIterable, Sendable {
    case html, react, next, vue
    public var label: String {
        switch self {
        case .html: return "HTML <picture>"
        case .react: return "React"
        case .next: return "Next.js"
        case .vue: return "Vue"
        }
    }
}
```
In `AppStore.swift`, REMOVE the nested `public enum SnippetFramework { … }` and keep `public var framework: SnippetFramework = .html` (now referring to the top-level type). Leave `SheetKind` as-is.

- [ ] **Step 2: Test** — `Tests/WebPicCoreTests/SnippetGeneratorTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class SnippetGeneratorTests: XCTestCase {
    private func input(lazy: Bool = true, formats: [ImageFormat] = [.avif, .webp, .jpeg]) -> SnippetInput {
        SnippetInput(baseName: "hero", formats: formats, width: 1200, height: 600,
                     lazy: lazy, responsive: false, breakpoints: [])
    }

    func testHTML() {
        let expected = """
        <picture>
          <source srcset="/img/hero.avif" type="image/avif">
          <source srcset="/img/hero.webp" type="image/webp">
          <img src="/img/hero.jpg" alt="" width="1200" height="600" loading="lazy" decoding="async">
        </picture>
        """
        XCTAssertEqual(SnippetGenerator.code(framework: .html, input: input()), expected)
    }

    func testLazyOff() {
        let out = SnippetGenerator.code(framework: .html, input: input(lazy: false))
        XCTAssertFalse(out.contains("loading=\"lazy\""))
        XCTAssertTrue(out.contains("decoding=\"async\""))
    }

    func testFallbackPNG() {
        let out = SnippetGenerator.code(framework: .html, input: input(formats: [.webp, .png]))
        XCTAssertTrue(out.contains("src=\"/img/hero.png\""))
        XCTAssertTrue(out.contains("type=\"image/webp\""))
        XCTAssertFalse(out.contains("image/avif"))
    }

    func testReactAndNextAndVue() {
        let react = SnippetGenerator.code(framework: .react, input: input())
        XCTAssertTrue(react.contains("srcSet=\"/img/hero.avif\""))
        XCTAssertTrue(react.contains("width={1200}"))
        let next = SnippetGenerator.code(framework: .next, input: input())
        XCTAssertTrue(next.contains("import Image from \"next/image\""))
        XCTAssertTrue(next.contains("<Image"))
        let vue = SnippetGenerator.code(framework: .vue, input: input())
        XCTAssertTrue(vue.hasPrefix("<template>"))
        XCTAssertTrue(vue.contains("<source srcset=\"/img/hero.webp\""))
    }
}
```

- [ ] **Step 3: Implement** — `Sources/WebPicCore/Snippets/SnippetGenerator.swift`
```swift
import Foundation

public struct SnippetInput: Sendable {
    public let baseName: String
    public let formats: [ImageFormat]
    public let width: Int
    public let height: Int
    public let lazy: Bool
    public let responsive: Bool
    public let breakpoints: [Int]
    public init(baseName: String, formats: [ImageFormat], width: Int, height: Int,
                lazy: Bool, responsive: Bool, breakpoints: [Int]) {
        self.baseName = baseName; self.formats = formats; self.width = width; self.height = height
        self.lazy = lazy; self.responsive = responsive; self.breakpoints = breakpoints
    }
}

public enum SnippetGenerator {
    /// Source formats emitted as <source> (avif then webp, if selected).
    static func sourceFormats(_ formats: [ImageFormat]) -> [ImageFormat] {
        [.avif, .webp].filter { formats.contains($0) }
    }
    /// Fallback <img>/<Image> format: png if selected, else jpg.
    static func fallback(_ formats: [ImageFormat]) -> String {
        formats.contains(.png) ? "png" : "jpg"
    }
    static func ext(_ f: ImageFormat) -> String {
        switch f { case .jpeg: return "jpg"; case .png: return "png"; case .avif: return "avif"; case .webp: return "webp" }
    }

    public static func code(framework: SnippetFramework, input i: SnippetInput) -> String {
        let base = i.baseName
        let fb = fallback(i.formats)
        let sources = sourceFormats(i.formats)
        let lz = i.lazy ? " loading=\"lazy\"" : ""
        switch framework {
        case .html:
            var l = ["<picture>"]
            for f in sources { l.append("  <source srcset=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\">") }
            l.append("  <img src=\"/img/\(base).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\">")
            l.append("</picture>")
            return l.joined(separator: "\n")
        case .react:
            var l = ["export function ProductImage() {", "  return (", "    <picture>"]
            for f in sources { l.append("      <source srcSet=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\" />") }
            l.append("      <img src=\"/img/\(base).\(fb)\" alt=\"\" width={\(i.width)} height={\(i.height)}\(lz) decoding=\"async\" />")
            l.append("    </picture>"); l.append("  );"); l.append("}")
            return l.joined(separator: "\n")
        case .next:
            let src = i.formats.contains(.webp) ? "webp" : fb
            var l = ["import Image from \"next/image\";", "", "export default function Hero() {", "  return (", "    <Image",
                     "      src=\"/img/\(base).\(src)\"", "      alt=\"\"", "      width={\(i.width)}", "      height={\(i.height)}"]
            if i.lazy { l.append("      loading=\"lazy\"") }
            l.append("    />"); l.append("  );"); l.append("}")
            return l.joined(separator: "\n")
        case .vue:
            var l = ["<template>", "  <picture>"]
            for f in sources { l.append("    <source srcset=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\" />") }
            l.append("    <img src=\"/img/\(base).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\" />")
            l.append("  </picture>"); l.append("</template>")
            return l.joined(separator: "\n")
        }
    }
}
```

- [ ] **Step 4: Run — PASS**, commit
```bash
swift test --filter SnippetGeneratorTests && swift build
git add Sources/WebPicCore/Snippets Sources/WebPicCore/AppStore.swift Tests/WebPicCoreTests/SnippetGeneratorTests.swift
git commit -m "feat: SnippetGenerator single-image (4 frameworks) + SnippetFramework (M6 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: Responsive srcset / sizes

**Goal:** When `responsive` is true, emit `srcset` with the breakpoint widths (+ a `sizes` attribute) instead of a single `srcset` URL.

**Files:**
- Modify: `Sources/WebPicCore/Snippets/SnippetGenerator.swift`
- Test: `Tests/WebPicCoreTests/SnippetResponsiveTests.swift`

**Acceptance Criteria:**
- [ ] responsive HTML `<source>` uses `srcset="/img/hero-400.avif 400w, /img/hero-800.avif 800w"` for breakpoints [400,800] and includes `sizes="100vw"`
- [ ] the `<img>` fallback `src` uses the largest breakpoint width (`/img/hero-800.jpg`)
- [ ] non-responsive output is unchanged (Task 0 tests still pass)

**Verify:** `swift test --filter SnippetResponsiveTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/SnippetResponsiveTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class SnippetResponsiveTests: XCTestCase {
    private func responsiveInput() -> SnippetInput {
        SnippetInput(baseName: "hero", formats: [.avif, .webp, .jpeg], width: 800, height: 400,
                     lazy: true, responsive: true, breakpoints: [400, 800])
    }
    func testResponsiveHTMLSrcset() {
        let out = SnippetGenerator.code(framework: .html, input: responsiveInput())
        XCTAssertTrue(out.contains("srcset=\"/img/hero-400.avif 400w, /img/hero-800.avif 800w\""))
        XCTAssertTrue(out.contains("sizes=\"100vw\""))
        XCTAssertTrue(out.contains("src=\"/img/hero-800.jpg\""))   // largest breakpoint as fallback
    }
}
```

- [ ] **Step 2: Implement** — add a responsive branch. Add helpers to `SnippetGenerator`:
```swift
    static func srcset(base: String, format: ImageFormat, breakpoints: [Int]) -> String {
        breakpoints.sorted().map { "/img/\(base)-\($0).\(ext(format)) \($0)w" }.joined(separator: ", ")
    }
    static func largestWidth(_ breakpoints: [Int], fallback: Int) -> Int {
        breakpoints.max() ?? fallback
    }
```
Then in `code(framework:input:)`, when `i.responsive && !i.breakpoints.isEmpty`, build the HTML/React/Vue `<source>` with the multi-width `srcset` + a `sizes="100vw"` attribute, and the fallback `<img>`/`src` using `largestWidth`. Keep the single-image path for `!responsive`. (Next.js `<Image>` handles responsive automatically — keep it emitting the single `src` at the largest width, with a `sizes="100vw"` prop when responsive.)

Recommended concrete shape for HTML responsive:
```
<picture>
  <source srcset="/img/hero-400.avif 400w, /img/hero-800.avif 800w" sizes="100vw" type="image/avif">
  <source srcset="/img/hero-400.webp 400w, /img/hero-800.webp 800w" sizes="100vw" type="image/webp">
  <img src="/img/hero-800.jpg" alt="" width="800" height="400" loading="lazy" decoding="async">
</picture>
```

- [ ] **Step 3: Run — PASS** (both snippet test files), commit
```bash
swift test --filter Snippet && swift build
git add Sources/WebPicCore/Snippets/SnippetGenerator.swift Tests/WebPicCoreTests/SnippetResponsiveTests.swift
git commit -m "feat: responsive srcset/sizes in SnippetGenerator (M6 task 1)"
```

---

### Task 2: Syntax tokenizer

**Goal:** A pure, round-trippable tokenizer that classifies code into tags/strings/attributes/keywords/comments for coloring.

**Files:**
- Create: `Sources/WebPicCore/Snippets/SyntaxHighlighter.swift`
- Test: `Tests/WebPicCoreTests/SyntaxHighlighterTests.swift`

**Acceptance Criteria:**
- [ ] `tokenize` is round-trippable: concatenating all token texts equals the input exactly
- [ ] a `<source srcset="x" />` snippet yields at least one `.tag`, one `.attribute`, and one `.string` token
- [ ] a Next.js snippet yields at least one `.keyword` token (`import`/`export`/`function`/`return`/`default`/`from`)

**Verify:** `swift test --filter SyntaxHighlighterTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/SyntaxHighlighterTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class SyntaxHighlighterTests: XCTestCase {
    func testRoundTrip() {
        let code = "<img src=\"/img/hero.jpg\" width={1200} />"
        let tokens = SyntaxHighlighter.tokenize(code)
        XCTAssertEqual(tokens.map(\.text).joined(), code)
    }
    func testKinds() {
        let code = "<source srcset=\"x\" />"
        let kinds = Set(SyntaxHighlighter.tokenize(code).map(\.kind))
        XCTAssertTrue(kinds.contains(.tag))
        XCTAssertTrue(kinds.contains(.attribute))
        XCTAssertTrue(kinds.contains(.string))
    }
    func testKeywords() {
        let code = "import Image from \"next/image\";"
        let kinds = SyntaxHighlighter.tokenize(code).map(\.kind)
        XCTAssertTrue(kinds.contains(.keyword))
    }
}
```

- [ ] **Step 2: Implement** — `Sources/WebPicCore/Snippets/SyntaxHighlighter.swift`
```swift
import Foundation

public enum TokenKind: Sendable, Hashable { case text, tag, string, attribute, keyword, comment }

public struct CodeToken: Sendable, Equatable {
    public let text: String
    public let kind: TokenKind
    public init(_ text: String, _ kind: TokenKind) { self.text = text; self.kind = kind }
}

public enum SyntaxHighlighter {
    private static let keywords: Set<String> = ["import", "export", "default", "function", "return", "from"]

    /// Tokenize for coloring. Round-trippable: tokens.map(\.text).joined() == input.
    public static func tokenize(_ code: String) -> [CodeToken] {
        // Pattern order matters: strings, tag delimiters, keywords, attribute-names.
        let pattern = #"("(?:[^"\\]|\\.)*")|(</?[A-Za-z][\w.-]*|/?>)|\b(import|export|default|function|return|from)\b|([A-Za-z-]+)(?=\s*=)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = code as NSString
        var out: [CodeToken] = []
        var last = 0
        for m in regex.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                out.append(CodeToken(ns.substring(with: NSRange(location: last, length: m.range.location - last)), .text))
            }
            let txt = ns.substring(with: m.range)
            let kind: TokenKind
            if m.range(at: 1).location != NSNotFound { kind = .string }
            else if m.range(at: 2).location != NSNotFound { kind = .tag }
            else if m.range(at: 3).location != NSNotFound { kind = .keyword }
            else { kind = .attribute }
            out.append(CodeToken(txt, kind))
            last = m.range.location + m.range.length
        }
        if last < ns.length {
            out.append(CodeToken(ns.substring(from: last), .text))
        }
        return out
    }
}
```

- [ ] **Step 3: Run — PASS**, commit
```bash
swift test --filter SyntaxHighlighterTests
git add Sources/WebPicCore/Snippets/SyntaxHighlighter.swift Tests/WebPicCoreTests/SyntaxHighlighterTests.swift
git commit -m "feat: syntax tokenizer for code snippets (M6 task 2)"
```

---

### Task 3: Code sheet UI + AppStore wiring + screenshot

**Goal:** The Code-Snippet sheet — framework segmented, highlighted code, Copy button with "Kopiert" feedback, `loading="lazy"` toggle — overlaying when `store.sheet == .code`, driven by real generator output.

**Files:**
- Create: `Sources/WebPicApp/Snippets/CodeSheet.swift`
- Create: `Sources/WebPicApp/Snippets/HighlightedCode.swift`
- Modify: `Sources/WebPicApp/RootView.swift` (present the sheet as an overlay)

**Acceptance Criteria:**
- [ ] when `store.sheet == .code`, a sheet shows: framework segmented (HTML `<picture>`/React/Next.js/Vue) bound to `store.framework`; the generated code (monospaced, colored tokens); a Copy button that writes to `NSPasteboard` and shows "Kopiert" for ~1.5s; a `loading="lazy"` toggle bound to `store.lazyLoading`
- [ ] the code updates live when framework / lazy / selected image / settings change
- [ ] closing (× or backdrop) sets `store.sheet = nil`
- [ ] `swift build` succeeds

**Verify:** `swift build` + screenshot (launch with `WEBPIC_IMPORT`, open the code sheet).

**Steps:**

- [ ] **Step 1: HighlightedCode view** — `Sources/WebPicApp/Snippets/HighlightedCode.swift`
```swift
import SwiftUI
import WebPicCore

struct HighlightedCode: View {
    let code: String
    @Environment(\.wpPalette) private var p

    private func color(_ kind: TokenKind) -> Color {
        switch kind {
        case .text: return p.t1
        case .tag: return Color(hex: 0xE5709F)
        case .string: return Color(hex: 0xE0913A)
        case .attribute: return Color(hex: 0x9C7BFF)
        case .keyword: return Color(hex: 0x5AB0FF)
        case .comment: return p.t3
        }
    }

    var body: some View {
        let tokens = SyntaxHighlighter.tokenize(code)
        var str = AttributedString()
        for t in tokens {
            var seg = AttributedString(t.text)
            seg.foregroundColor = color(t.kind)
            str += seg
        }
        return Text(str)
            .font(.system(size: 12.5, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

- [ ] **Step 2: CodeSheet** — `Sources/WebPicApp/Snippets/CodeSheet.swift`
```swift
import SwiftUI
import AppKit
import WebPicCore

struct CodeSheet: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p
    @State private var copied = false

    private var code: String {
        guard let img = store.selected else { return "" }
        let r = store.primaryResult
        let w = r?.width ?? img.pixelWidth
        let h = r?.height ?? img.pixelHeight
        let base = (img.name as NSString).deletingPathExtension
        let formats: [ImageFormat] = [.avif, .webp, .jpeg, .png].filter { store.settings.formats.contains($0) }
        let input = SnippetInput(baseName: base, formats: formats, width: w, height: h,
                                 lazy: store.lazyLoading, responsive: store.settings.outputMode == .responsive,
                                 breakpoints: store.settings.breakpoints.sorted())
        return SnippetGenerator.code(framework: store.framework, input: input)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea().onTapGesture { store.sheet = nil }
            VStack(spacing: 0) {
                HStack {
                    Text("Code-Snippet").font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button { store.sheet = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).foregroundStyle(p.t2)
                        .frame(width: 26, height: 26).background(p.seg, in: RoundedRectangle(cornerRadius: 7))
                }.padding(.horizontal, 18).padding(.top, 15).padding(.bottom, 13)

                Picker("", selection: $store.framework) {
                    ForEach(SnippetFramework.allCases, id: \.self) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 18).padding(.bottom, 14)

                ZStack(alignment: .topTrailing) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HighlightedCode(code: code).padding(16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xF6F6F9), in: RoundedRectangle(cornerRadius: 11))
                    Button { copy() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12))
                            Text(copied ? "Kopiert" : "Kopieren").font(.system(size: 12, weight: .medium))
                        }.padding(.horizontal, 11).frame(height: 28)
                        .background(copied ? p.statusDone : p.ctrl, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(copied ? .white : p.t1)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.ctrlBorder, lineWidth: 0.5))
                    }.buttonStyle(.plain).padding(10)
                }.padding(.horizontal, 18)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("loading=\"lazy\" einschließen").font(.system(size: 13, weight: .medium))
                        Text("Verzögertes Laden für Bilder außerhalb des Viewports").font(.system(size: 12)).foregroundStyle(p.t3)
                    }
                    Spacer()
                    Toggle("", isOn: $store.lazyLoading).labelsHidden().toggleStyle(.switch).tint(p.accent)
                }.padding(.horizontal, 18).padding(.vertical, 15)
            }
            .frame(width: 620)
            .background(p.window, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 14)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        Task { try? await Task.sleep(nanoseconds: 1_600_000_000); copied = false }
    }
}
```
> Note: `store.lazyLoading` / `store.framework` are already `AppStore` vars. `p.window` and `p.ctrl` exist in WPPalette.

- [ ] **Step 3: Present from RootView** — in `RootView.body`, overlay the sheet:
```swift
        .overlay {
            if store.sheet == .code {
                CodeSheet(store: store)
                    .environment(\.wpPalette, palette)
            }
        }
```
`RootView` reads `store` — add `@Environment(AppStore.self) private var store` if not present, and pass it. (RootView currently only has `theme`; add the store environment and use it for the overlay.)

- [ ] **Step 4: Build + commit**
```bash
swift build && swift test
git add Sources/WebPicApp/Snippets Sources/WebPicApp/RootView.swift
git commit -m "feat: Code-Snippet sheet (framework segmented, highlighted, copy, lazy) (M6 task 3)"
```
Controller then screenshots the sheet (launch with `WEBPIC_IMPORT`, `store.sheet` opened — add a `WEBPIC_SHEET=code` hook if needed for deterministic capture).

---

## Milestone 6 acceptance
- [ ] `swift build` + `swift test` green
- [ ] Snippets are copy-paste-correct for all four frameworks (single + responsive), matching the reference
- [ ] `loading="lazy"` toggle works; syntax coloring renders; Copy writes to clipboard with feedback
- [ ] Screenshot verified

## Notes for later milestones
- **M7 Batch**: grid + concurrent processing (bounded parallelism per M4 note) + real per-image progress.
- **M8**: Sparkle update + packaging/notarization decision.
- Snippet `sizes="100vw"` is a sensible default; a future enhancement could let the user set `sizes`.
- Carry the M5 items forward (keepMetadata honoring, Photos-origin source data).

### Carry-forward from M6 code review
- **Fixed in-milestone:** the Critical dimension bug (snippet emitted original pixel dims when opened before processing) — now uses `EstimationService.newDimensions`.
- **Minor (deferred):** the tokenizer dropped the reference's comment + `{number}` highlight groups, so `.comment` is an unreachable `TokenKind` case and numbers render as plain text (cosmetic). Restore the groups or drop the case for fidelity.
- **Minor:** `CodeSheet.copied` reset Task isn't cancelled on dismiss/rapid re-copy (benign; use `.task(id:)` if tightening).
- **Minor:** responsive Next.js emits `sizes` without `srcSet` (inert; `next/image` handles responsive itself).
