# WebPic Milestone 8 — Auto-Update + Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers-extended-cc:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A lightweight GitHub-Releases update checker + the update banner/modal from the design, plus DMG packaging with documented Gatekeeper bypass. Final milestone.

**Architecture:** `AppVersion` (semantic compare) + `ReleaseInfo` + a pure `parseLatestRelease(_:)` (GitHub JSON → ReleaseInfo). `UpdateChecker.fetchLatest` does the async GitHub API call and returns a `ReleaseInfo` only if newer than the current version. `AppStore.checkForUpdate()` populates `availableUpdate` + `showUpdate`; the sidebar banner and the `UpdateSheet` modal read it; "Installieren" opens the download URL via `NSWorkspace`. `Scripts/make-dmg.sh` builds an unsigned DMG; README documents the one-time bypass.

**Decisions (confirmed):** lightweight GitHub-Releases checker (NOT Sparkle); unsigned DMG + documented right-click→Open (no paid Apple Developer account → no notarization).

**Tech Stack:** Swift 6, SwiftUI, URLSession, AppKit (`NSWorkspace`), `hdiutil`.

**Reference:** update banner (`WebPic.dc.html` ~100–106) + update modal (~479–510). Builds on M1–M7. Repo: `Flogut1308/webpic`.

---

### Task 0: AppVersion + ReleaseInfo + release JSON parsing

**Goal:** Pure version comparison and GitHub-release JSON parsing.

**Files:**
- Create: `Sources/WebPicCore/Update/AppVersion.swift`, `Sources/WebPicCore/Update/ReleaseInfo.swift`, `Sources/WebPicCore/Update/UpdateChecker.swift` (parse only in this task)
- Test: `Tests/WebPicCoreTests/UpdateParsingTests.swift`

**Acceptance Criteria:**
- [ ] `AppVersion("2.1") > AppVersion("2.0")`, `AppVersion("2.10") > AppVersion("2.9")`, equal versions not greater; a leading `v` is tolerated
- [ ] `parseLatestRelease` on a sample GitHub JSON returns version (tag without `v`), changelog lines (body split, `- ` stripped), the `.dmg` asset download URL + size, falling back to `html_url` when no dmg asset
- [ ] malformed JSON → nil

**Verify:** `swift test --filter UpdateParsingTests`

**Steps:**

- [ ] **Step 1: Test** — `Tests/WebPicCoreTests/UpdateParsingTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class UpdateParsingTests: XCTestCase {
    func testVersionCompare() {
        XCTAssertTrue(AppVersion("2.1") > AppVersion("2.0"))
        XCTAssertTrue(AppVersion("2.10") > AppVersion("2.9"))
        XCTAssertTrue(AppVersion("v2.1") > AppVersion("2.0"))
        XCTAssertFalse(AppVersion("2.0") > AppVersion("2.0"))
        XCTAssertEqual(AppVersion("2.0"), AppVersion("2.0"))
    }

    func testParseRelease() {
        let json = """
        {
          "tag_name": "v2.1",
          "html_url": "https://github.com/Flogut1308/webpic/releases/tag/v2.1",
          "body": "- AVIF-Encoder um bis zu 3× schneller\\n- Neues Next.js-Snippet\\n- EXIF-Fix",
          "assets": [
            { "browser_download_url": "https://github.com/Flogut1308/webpic/releases/download/v2.1/WebPic.dmg", "size": 14680064 }
          ]
        }
        """.data(using: .utf8)!
        let info = UpdateChecker.parseLatestRelease(json)!
        XCTAssertEqual(info.version, "2.1")
        XCTAssertEqual(info.notes.count, 3)
        XCTAssertEqual(info.notes.first, "AVIF-Encoder um bis zu 3× schneller")
        XCTAssertEqual(info.downloadURL.absoluteString, "https://github.com/Flogut1308/webpic/releases/download/v2.1/WebPic.dmg")
        XCTAssertEqual(info.sizeBytes, 14680064)
    }

    func testParseReleaseNoDMGFallsBackToHTMLURL() {
        let json = """
        {"tag_name":"2.2","html_url":"https://example.com/rel","body":"- x","assets":[]}
        """.data(using: .utf8)!
        let info = UpdateChecker.parseLatestRelease(json)!
        XCTAssertEqual(info.version, "2.2")
        XCTAssertEqual(info.downloadURL.absoluteString, "https://example.com/rel")
        XCTAssertNil(info.sizeBytes)
    }

    func testMalformed() {
        XCTAssertNil(UpdateChecker.parseLatestRelease("not json".data(using: .utf8)!))
    }
}
```

- [ ] **Step 2: AppVersion** — `Sources/WebPicCore/Update/AppVersion.swift`
```swift
import Foundation

public struct AppVersion: Comparable, Equatable, Sendable {
    public let components: [Int]
    public init(_ string: String) {
        let cleaned = string.hasPrefix("v") ? String(string.dropFirst()) : string
        components = cleaned.split(separator: ".").map { Int($0) ?? 0 }
    }
    public static func < (l: AppVersion, r: AppVersion) -> Bool {
        let n = max(l.components.count, r.components.count)
        for i in 0..<n {
            let a = i < l.components.count ? l.components[i] : 0
            let b = i < r.components.count ? r.components[i] : 0
            if a != b { return a < b }
        }
        return false
    }
}
```

- [ ] **Step 3: ReleaseInfo** — `Sources/WebPicCore/Update/ReleaseInfo.swift`
```swift
import Foundation

public struct ReleaseInfo: Equatable, Sendable {
    public let version: String
    public let notes: [String]
    public let downloadURL: URL
    public let sizeBytes: Int?
    public init(version: String, notes: [String], downloadURL: URL, sizeBytes: Int?) {
        self.version = version; self.notes = notes; self.downloadURL = downloadURL; self.sizeBytes = sizeBytes
    }
}
```

- [ ] **Step 4: parseLatestRelease** — `Sources/WebPicCore/Update/UpdateChecker.swift`
```swift
import Foundation

public enum UpdateChecker {
    public static func parseLatestRelease(_ data: Data) -> ReleaseInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let body = (obj["body"] as? String) ?? ""
        let notes = body.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }
            .filter { !$0.isEmpty }
        let assets = (obj["assets"] as? [[String: Any]]) ?? []
        let dmg = assets.first { ($0["browser_download_url"] as? String)?.hasSuffix(".dmg") == true }
        let urlString = (dmg?["browser_download_url"] as? String) ?? (obj["html_url"] as? String)
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let size = dmg?["size"] as? Int
        return ReleaseInfo(version: version, notes: notes, downloadURL: url, sizeBytes: size)
    }
}
```

- [ ] **Step 5: Run — PASS**, commit
```bash
swift test --filter UpdateParsingTests && swift build
git add Sources/WebPicCore/Update Tests/WebPicCoreTests/UpdateParsingTests.swift
git commit -m "feat: AppVersion + ReleaseInfo + GitHub release JSON parsing (M8 task 0)"
```
(Commit body ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.)

---

### Task 1: UpdateChecker.fetchLatest + AppStore wiring

**Goal:** Async GitHub API fetch (returns a newer `ReleaseInfo` or nil) and `AppStore` state/actions.

**Files:**
- Modify: `Sources/WebPicCore/Update/UpdateChecker.swift` (add `fetchLatest`)
- Modify: `Sources/WebPicCore/AppStore.swift` (`availableUpdate`, `checkForUpdate`, `openUpdateDownload`; change `showUpdate` default to `false`)
- Test: `Tests/WebPicCoreTests/UpdateCheckerTests.swift`

**Acceptance Criteria:**
- [ ] `fetchLatest` returns nil when the latest version is not newer than current (uses `parseLatestRelease` + `AppVersion` compare) — tested via an injectable data loader (no live network)
- [ ] `AppStore.availableUpdate` defaults nil; `showUpdate` defaults false
- [ ] `checkForUpdate()` sets `availableUpdate` and `showUpdate = (availableUpdate != nil)`

**Verify:** `swift test --filter UpdateCheckerTests`

**Steps:**

- [ ] **Step 1: fetchLatest with injectable loader** — add to `UpdateChecker`:
```swift
    /// Returns the latest release ONLY if newer than `currentVersion`.
    /// `loader` is injectable for testing; defaults to a real GitHub API call.
    public static func fetchLatest(
        owner: String, repo: String, currentVersion: String,
        loader: (URL) async -> Data? = { url in
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            return try? await URLSession.shared.data(for: req).0
        }
    ) async -> ReleaseInfo? {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        guard let data = await loader(url), let info = parseLatestRelease(data) else { return nil }
        guard AppVersion(info.version) > AppVersion(currentVersion) else { return nil }
        return info
    }
```

- [ ] **Step 2: Test** — `Tests/WebPicCoreTests/UpdateCheckerTests.swift`
```swift
import XCTest
@testable import WebPicCore

final class UpdateCheckerTests: XCTestCase {
    private func json(_ version: String) -> Data {
        """
        {"tag_name":"\(version)","html_url":"https://x/rel","body":"- new","assets":[]}
        """.data(using: .utf8)!
    }

    func testReturnsNewer() async {
        let info = await UpdateChecker.fetchLatest(owner: "o", repo: "r", currentVersion: "2.0",
                                                   loader: { _ in self.json("2.1") })
        XCTAssertEqual(info?.version, "2.1")
    }

    func testNilWhenNotNewer() async {
        let info = await UpdateChecker.fetchLatest(owner: "o", repo: "r", currentVersion: "2.0",
                                                   loader: { _ in self.json("2.0") })
        XCTAssertNil(info)
    }

    func testNilOnLoaderFailure() async {
        let info = await UpdateChecker.fetchLatest(owner: "o", repo: "r", currentVersion: "2.0",
                                                   loader: { _ in nil })
        XCTAssertNil(info)
    }
}
```

- [ ] **Step 3: AppStore wiring** — in `AppStore`:
  - Change `public var showUpdate: Bool = true` → `= false`.
  - Add:
```swift
    public var availableUpdate: ReleaseInfo? = nil

    @MainActor
    public func checkForUpdate() async {
        let info = await UpdateChecker.fetchLatest(owner: "Flogut1308", repo: "webpic",
                                                   currentVersion: WebPicCore.version)
        availableUpdate = info
        showUpdate = (info != nil)
    }
```
  - (The actual "open download" action lives in the app layer via `NSWorkspace`; expose the URL through `availableUpdate?.downloadURL`.)

- [ ] **Step 4: Run — PASS**, commit
```bash
swift test --filter UpdateCheckerTests && swift build
git add Sources/WebPicCore/Update/UpdateChecker.swift Sources/WebPicCore/AppStore.swift Tests/WebPicCoreTests/UpdateCheckerTests.swift
git commit -m "feat: UpdateChecker.fetchLatest + AppStore update state (M8 task 1)"
```

---

### Task 2: Update modal + banner wiring + screenshot

**Goal:** The update modal (`sheet == .update`) from the reference, the sidebar banner reading real `availableUpdate`, and "Installieren" opening the download. Check for updates on launch.

**Files:**
- Create: `Sources/WebPicApp/Update/UpdateSheet.swift`
- Modify: `Sources/WebPicApp/RootView.swift` (overlay `UpdateSheet` when `sheet == .update`)
- Modify: `Sources/WebPicApp/Sidebar/SidebarView.swift` (banner shows real version; already gated on `store.showUpdate`)
- Modify: `Sources/WebPicApp/WebPicMain.swift` (mock `availableUpdate` when `WEBPIC_UPDATE=1`, for screenshots; real `checkForUpdate` on launch)

**Acceptance Criteria:**
- [ ] modal shows: gradient icon, "WebPic <version> ist verfügbar", "Du hast Version <current> · Update ca. <size>", changelog bullets, "Später" (dismiss) / "Installieren & neu starten" (opens `downloadURL` via `NSWorkspace`), footer "Automatisch aktualisiert über GitHub-Releases"
- [ ] sidebar banner text uses the real available version; tapping opens the modal
- [ ] on normal launch, `checkForUpdate()` runs (no crash if offline → banner hidden)
- [ ] `WEBPIC_UPDATE=1` injects a mock `availableUpdate` so the modal/banner render for screenshots
- [ ] `swift build` succeeds

**Verify:** `swift build` + screenshot (launch with `WEBPIC_UPDATE=1 WEBPIC_SHEET=update`).

**Steps:**

- [ ] **Step 1: UpdateSheet** — `Sources/WebPicApp/Update/UpdateSheet.swift`
```swift
import SwiftUI
import AppKit
import WebPicCore

struct UpdateSheet: View {
    @Bindable var store: AppStore
    @Environment(\.wpPalette) private var p

    private var info: ReleaseInfo? { store.availableUpdate }

    private var sizeText: String {
        guard let b = info?.sizeBytes else { return "" }
        return " · Update ca. \(formatBytes(b))"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea().onTapGesture { store.sheet = nil }
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [p.accent, Color(hex: 0x5AC8FA)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .overlay { Image(systemName: "arrow.down.circle").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white) }
                        .padding(.bottom, 16)
                    Text("WebPic \(info?.version ?? "") ist verfügbar").font(.system(size: 18, weight: .bold))
                    Text("Du hast Version \(WebPicCore.version)\(sizeText)").font(.system(size: 13)).foregroundStyle(p.t2).padding(.top, 4)
                }.padding(.horizontal, 26).padding(.top, 26).padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 9) {
                    Text("NEU IN DIESER VERSION").font(.system(size: 11, weight: .semibold)).kerning(0.3).foregroundStyle(p.t3)
                    ForEach(Array((info?.notes ?? []).enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 9) {
                            Text("·").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent)
                            Text(note).font(.system(size: 13)).foregroundStyle(p.t1)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                .background(p.grouped, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20)

                HStack(spacing: 10) {
                    Button("Später") { store.sheet = nil }.buttonStyle(.bordered).controlSize(.large)
                    Button {
                        if let url = info?.downloadURL { NSWorkspace.shared.open(url) }
                        store.sheet = nil
                    } label: { Text("Installieren & neu starten").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(p.accent)
                }.padding(20)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11))
                    Text("Automatisch aktualisiert über GitHub-Releases").font(.system(size: 11))
                }.foregroundStyle(p.t3).padding(.bottom, 16)
            }
            .frame(width: 400)
            .background(p.window, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        }
    }
}
```

- [ ] **Step 2: Overlay in RootView** — extend the existing `.overlay` (which already handles `.code`) to also present `UpdateSheet` when `store.sheet == .update`:
```swift
        .overlay {
            if store.sheet == .code {
                CodeSheet(store: store).environment(\.wpPalette, palette)
            } else if store.sheet == .update {
                UpdateSheet(store: store).environment(\.wpPalette, palette)
            }
        }
```

- [ ] **Step 3: Banner text** — in `SidebarView`, the update pill currently shows a hardcoded "Update 2.1 verfügbar". Change it to use the real version when available:
```swift
                if store.showUpdate {
                    Button { store.sheet = .update } label: {
                        HStack(spacing: 8) {
                            Circle().fill(p.accent).frame(width: 7, height: 7)
                            Text("Update \(store.availableUpdate?.version ?? "") verfügbar")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(p.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(p.accent)
                        }
                        ... (keep existing padding/background)
                    }.buttonStyle(.plain)
                }
```

- [ ] **Step 4: Launch check + screenshot mock** — in `WebPicMain.init`, add after the other hooks:
```swift
        if env["WEBPIC_UPDATE"] == "1" {
            store.availableUpdate = ReleaseInfo(
                version: "2.1", notes: ["AVIF-Encoder um bis zu 3× schneller",
                                        "Neues Next.js-Snippet mit sizes", "Fehler beim Beibehalten von EXIF behoben"],
                downloadURL: URL(string: "https://github.com/Flogut1308/webpic/releases/latest")!, sizeBytes: 14_680_064)
            store.showUpdate = true
        } else {
            Task { await store.checkForUpdate() }   // real check on launch
        }
```

- [ ] **Step 5: Build + commit**
```bash
swift build && swift test
git add Sources/WebPicApp/Update Sources/WebPicApp/RootView.swift Sources/WebPicApp/Sidebar/SidebarView.swift Sources/WebPicApp/WebPicMain.swift
git commit -m "feat: update modal + banner wiring + launch check (M8 task 2)"
```
Controller then screenshots the modal (`WEBPIC_UPDATE=1 WEBPIC_SHEET=update WEBPIC_IMPORT=…`).

---

### Task 3: DMG packaging + distribution docs

**Goal:** A script that builds an unsigned `WebPic.dmg` from the `.app`, and README docs for the one-time Gatekeeper bypass.

**Files:**
- Create: `Scripts/make-dmg.sh`
- Modify: `README.md` (Install / distribution section)

**Acceptance Criteria:**
- [ ] `bash Scripts/make-dmg.sh` (after `bundle.sh`) produces `dist/WebPic.dmg` containing `WebPic.app` + an Applications symlink
- [ ] README documents the right-click→Open / `xattr -d com.apple.quarantine` bypass and that the build is unsigned (no paid Apple Developer account yet)
- [ ] the DMG mounts and shows the app (verified by the controller)

**Verify:** `bash Scripts/bundle.sh release && bash Scripts/make-dmg.sh` → `dist/WebPic.dmg` exists and mounts.

**Steps:**

- [ ] **Step 1: make-dmg.sh** — `Scripts/make-dmg.sh`
```bash
#!/bin/bash
set -euo pipefail
APP="dist/WebPic.app"
[ -d "$APP" ] || { echo "Build the app first: bash Scripts/bundle.sh release"; exit 1; }
STAGING="dist/dmg-staging"
DMG="dist/WebPic.dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "WebPic" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"
echo "Built $DMG"
```

- [ ] **Step 2: README** — add an "## Installation" section documenting:
  - download `WebPic.dmg` from the GitHub Releases page, drag WebPic to Applications;
  - **first launch:** the app is **not notarized** (no Apple Developer account yet), so macOS Gatekeeper will warn — **right-click the app → Open → Open**, or run `xattr -dr com.apple.quarantine /Applications/WebPic.app`;
  - note that auto-update checks GitHub Releases and opens the latest DMG download.

- [ ] **Step 3: Verify + commit**
```bash
chmod +x Scripts/make-dmg.sh
bash Scripts/bundle.sh release && bash Scripts/make-dmg.sh
git add Scripts/make-dmg.sh README.md
git commit -m "feat: DMG packaging script + install/bypass docs (M8 task 3)"
```
Controller mounts the DMG to confirm.

---

## Milestone 8 acceptance
- [ ] `swift build` + `swift test` green
- [ ] Update check queries GitHub Releases; banner + modal show the real available version/changelog; "Installieren" opens the download
- [ ] `make-dmg.sh` produces a mountable `WebPic.dmg`; README documents the unsigned-app bypass
- [ ] Screenshot verified (update modal)

## Notes / project close-out
- App is **unsigned / not notarized** (no paid Apple Developer account). To ship notarized later: get the $99/yr account + Developer ID cert, `codesign` the .app, `notarytool submit` the DMG, `stapler staple`.
- Sparkle 2 (silent in-app auto-install) is a future upgrade once the app is signed — the current checker + "open download" is the honest MVP.
- Outstanding cross-milestone carry-forwards (non-blocking): unify `processSelected`/`processAll` encode paths; honor `keepMetadata` (EXIF/ICC copy-through); per-image batch settings; downsampled Compare preview for very large images.
